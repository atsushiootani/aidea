//
//  RecommendStore.swift
//  Aidea
//

import Foundation

/// Scene ごとのレコメンド設定（プロンプト + デフォルトコンパニオン）
struct SceneConfig: Codable {
    var prompts: [String]
    var defaultCompanionIndex: Int

    init(prompts: [String] = [], defaultCompanionIndex: Int = 0) {
        self.prompts = prompts
        self.defaultCompanionIndex = defaultCompanionIndex
    }
}

/// Scene ごとのレコメンドプロンプトとデフォルトコンパニオンを永続化する。
/// `.aidea/recommends.json` に保存する。
enum RecommendStore {
    private static var configURL: URL?

    /// プロジェクトルートを設定する
    static func setup(projectRoot: URL) {
        configURL = projectRoot.appending(path: ".aidea/recommends.json")
    }

    /// 全データを読み込む
    static func loadAll() -> [String: SceneConfig] {
        guard let url = configURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return [:]
        }
        // 新フォーマット
        if let dict = try? JSONDecoder().decode([String: SceneConfig].self, from: data) {
            return dict
        }
        // 旧フォーマット（[String: [String]]）からのマイグレーション
        if let old = try? JSONDecoder().decode([String: [String]].self, from: data) {
            return old.mapValues { SceneConfig(prompts: $0) }
        }
        return [:]
    }

    /// 指定 Scene の設定を取得する
    static func config(for scene: String) -> SceneConfig? {
        loadAll()[scene]
    }

    /// 指定 Scene のプロンプトを取得する
    static func prompts(for scene: String) -> [String]? {
        config(for: scene)?.prompts
    }

    /// 指定 Scene のデフォルトコンパニオンインデックスを取得する
    static func defaultCompanionIndex(for scene: String) -> Int {
        config(for: scene)?.defaultCompanionIndex ?? 0
    }

    /// 指定 Scene のプロンプトを保存する
    static func save(scene: String, prompts: [String]) {
        var all = loadAll()
        var conf = all[scene] ?? SceneConfig()
        conf.prompts = prompts
        all[scene] = conf
        saveAll(all)
    }

    /// 指定 Scene のデフォルトコンパニオンを保存する
    static func saveDefaultCompanion(scene: String, index: Int) {
        var all = loadAll()
        var conf = all[scene] ?? SceneConfig()
        conf.defaultCompanionIndex = index
        all[scene] = conf
        saveAll(all)
    }

    /// 全データを保存する
    private static func saveAll(_ dict: [String: SceneConfig]) {
        guard let url = configURL else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(dict) {
            try? data.write(to: url)
        }
    }

    /// Scene に対するプロンプトを解決する（永続化 > デフォルト > 空）
    static func resolve(scene: String?, defaults: [String]) -> [String] {
        if let scene, let saved = prompts(for: scene), !saved.isEmpty {
            return saved
        }
        return defaults
    }
}
