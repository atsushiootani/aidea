//
//  InstanceLock.swift
//  Aidea
//

import Foundation
import AppKit

/// リポジトリ単位の排他ロック。1 つの projectRoot を 1 プロセスだけが開けるようにする。
/// `<projectRoot>/.aidea/.instance.lock` に所有プロセスの pid・bundleId・前面化用トークンを
/// 記録し、排他生成で 1 プロセスだけが取得できるようにする。異常終了で残った lock は、
/// 記録された pid が生きていない (または Aidea でない) ことを確認してから奪取する。
/// 詳細: docs/specs/window/multi-instance.md / ADR 0030
enum InstanceLock {
    /// lock ファイルに記録する所有プロセス情報
    struct Owner: Codable {
        /// 所有プロセスの pid
        let pid: Int32
        /// 所有プロセスの bundle identifier (pid 再利用による誤検出を防ぐため照合に使う)
        let bundleId: String
        /// 前面化要求を届けるための一意トークン
        let token: String
    }

    /// 取得結果
    enum AcquireResult {
        /// 自プロセスが lock を取得した (前面化通知の購読に使う token を返す)
        case acquired(token: String)
        /// 既に別プロセスが保持している (前面化に使う既存 owner を返す)
        case heldByOther(Owner)
    }

    /// lock ファイルの場所を返す
    private static func lockURL(for projectRoot: URL) -> URL {
        projectRoot
            .appending(path: ".aidea", directoryHint: .isDirectory)
            .appending(path: ".instance.lock", directoryHint: .notDirectory)
    }

    /// projectRoot の lock 取得を試みる。
    /// 取得できれば `.acquired`、既存の生存プロセスが保持していれば `.heldByOther` を返す。
    /// `.aidea/` に書き込めない (読み取り専用等) 場合は排他を諦めて `.acquired` 扱いにする。
    static func acquire(for projectRoot: URL) -> AcquireResult {
        let fm = FileManager.default
        let url = lockURL(for: projectRoot)
        let aideaDir = url.deletingLastPathComponent()
        try? fm.createDirectory(at: aideaDir, withIntermediateDirectories: true)

        // 既存 lock が生きているプロセスのものなら取得失敗 (前面化に使う owner を返す)
        if let owner = readOwner(at: url), isAlive(owner) {
            return .heldByOther(owner)
        }
        // stale (死んでいる / Aidea でない) lock は奪取するため削除する
        try? fm.removeItem(at: url)

        // 排他生成 (O_EXCL) で自プロセスの owner を書き込む
        let token = UUID().uuidString
        let owner = Owner(pid: getpid(), bundleId: Bundle.main.bundleIdentifier ?? "", token: token)
        // エンコード失敗は理論上起きないが、起きても排他を諦めて起動を続行する
        guard let data = try? JSONEncoder().encode(owner) else {
            return .acquired(token: token)
        }
        let fd = open(url.path, O_CREAT | O_EXCL | O_WRONLY, 0o644)
        if fd < 0 {
            // EEXIST: ほぼ同時に別プロセスが作った場合は、その owner を前面化対象として返す
            if let other = readOwner(at: url), isAlive(other) {
                return .heldByOther(other)
            }
            // 書き込めない (権限なし / 読み取り専用) 場合は排他を諦めて起動を続行する
            return .acquired(token: token)
        }
        data.withUnsafeBytes { _ = write(fd, $0.baseAddress, $0.count) }
        close(fd)
        return .acquired(token: token)
    }

    /// 自プロセスが保持している lock を解放する (ファイル削除)。
    /// 別プロセスの lock は触らない。
    static func release(for projectRoot: URL) {
        let url = lockURL(for: projectRoot)
        guard let owner = readOwner(at: url), owner.pid == getpid() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 既存 lock の owner を読む (無ければ nil)
    static func readOwner(at url: URL) -> Owner? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Owner.self, from: data)
    }

    /// owner のプロセスが生きていて、かつ Aidea プロセスかを判定する。
    /// pid 再利用で無関係なプログラムが同じ pid を持つ場合を bundleId 照合で除外する。
    static func isAlive(_ owner: Owner) -> Bool {
        guard owner.pid > 0 else { return false }
        // kill(pid, 0): プロセスが存在すれば 0、存在しなければ -1 (ESRCH)
        if kill(owner.pid, 0) != 0 { return false }
        // 同じ pid のプロセスが Aidea かを bundleId で照合する
        if let app = NSRunningApplication(processIdentifier: owner.pid) {
            return app.bundleIdentifier == owner.bundleId
        }
        return false
    }
}
