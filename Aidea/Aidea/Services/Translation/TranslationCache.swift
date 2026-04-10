//
//  TranslationCache.swift
//  Aidea
//

import Foundation

/// `.aidea/ja/` 配下に翻訳結果をキャッシュするサービス。
/// 元ファイルの相対パスをミラーした構造でキャッシュファイルを配置する。
enum TranslationCache {

    /// 元ファイルに対応するキャッシュファイルの URL を返す。
    /// - Parameters:
    ///   - originalURL: 元ファイルの絶対パス
    ///   - projectRoot: プロジェクトルート
    /// - Returns: `.aidea/ja/<相対パス>` のキャッシュ URL (nil = projectRoot 外のファイル)
    static func cachedURL(for originalURL: URL, projectRoot: URL) -> URL? {
        let originalPath = originalURL.standardizedFileURL.path
        let rootPath = projectRoot.standardizedFileURL.path
        guard originalPath.hasPrefix(rootPath) else { return nil }
        let relative = String(originalPath.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return projectRoot
            .appending(path: ".aidea/ja", directoryHint: .isDirectory)
            .appending(path: relative)
    }

    /// キャッシュが存在し、元ファイルより新しい (= 鮮度がある) か判定する。
    /// - Parameters:
    ///   - originalURL: 元ファイル URL
    ///   - cachedURL: キャッシュファイル URL
    /// - Returns: キャッシュが存在し鮮度がある場合 true
    static func isFresh(original originalURL: URL, cached cachedURL: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cachedURL.path) else { return false }
        guard let originalAttrs = try? fm.attributesOfItem(atPath: originalURL.path),
              let cachedAttrs = try? fm.attributesOfItem(atPath: cachedURL.path),
              let originalMtime = originalAttrs[.modificationDate] as? Date,
              let cachedMtime = cachedAttrs[.modificationDate] as? Date else {
            return false
        }
        return cachedMtime >= originalMtime
    }

    /// 翻訳結果をキャッシュファイルに保存する。中間ディレクトリは自動作成。
    /// - Parameters:
    ///   - text: 保存するテキスト
    ///   - url: 保存先のキャッシュ URL
    /// 指定 URL が `.aidea/ja/` 配下のキャッシュファイルかどうか判定する
    static func isCachedFile(_ url: URL) -> Bool {
        url.standardizedFileURL.path.contains("/.aidea/ja/")
    }

    /// キャッシュファイルの URL から元ファイルの URL を逆算する
    /// - Parameters:
    ///   - cachedURL: `.aidea/ja/<相対パス>` のキャッシュ URL
    ///   - projectRoot: プロジェクトルート
    /// - Returns: 元ファイルの URL (nil = 形式が合わない)
    static func originalURL(for cachedURL: URL, projectRoot: URL) -> URL? {
        let cachedPath = cachedURL.standardizedFileURL.path
        let jaDir = projectRoot.standardizedFileURL.path + "/.aidea/ja/"
        guard cachedPath.hasPrefix(jaDir) else { return nil }
        let relative = String(cachedPath.dropFirst(jaDir.count))
        return projectRoot.appending(path: relative)
    }

    static func save(text: String, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
