//
//  RecentProjectsStore.swift
//  Aidea
//

import Foundation

/// 最近開いたリポジトリ (MRU: Most Recently Used) を UserDefaults に保持する。
/// 複数プロセスが同時に動くため、保存は read-merge-write で行い、他プロセスが
/// 直前に開いたリポジトリを上書きで取りこぼさない。存在しなくなったディレクトリは
/// 一覧取得時に除外する。
/// 詳細: docs/specs/window/multi-instance.md / ADR 0030
enum RecentProjectsStore {
    private static let key = "aidea.recentProjects"
    /// 保持する最大件数
    private static let limit = 20

    /// 最近開いたリポジトリを新しい順に返す (実在するディレクトリのみ)
    static func list() -> [URL] {
        let fm = FileManager.default
        let paths = UserDefaults.standard.stringArray(forKey: key) ?? []
        return paths.compactMap { path in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    /// リポジトリを MRU の先頭に記録する。
    /// 保存直前に現在値を読み直してからマージする (read-merge-write) ため、
    /// 他プロセスが直前に記録したリポジトリを上書きで消さない。
    static func record(_ url: URL) {
        let path = url.standardizedFileURL.path
        var paths = UserDefaults.standard.stringArray(forKey: key) ?? []
        paths.removeAll { $0 == path }
        paths.insert(path, at: 0)
        if paths.count > limit {
            paths = Array(paths.prefix(limit))
        }
        UserDefaults.standard.set(paths, forKey: key)
    }
}
