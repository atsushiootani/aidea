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

/// Scene ごとのレコメンドプロンプトとデフォルトコンパニオンを管理する。
/// データは WorkspaceSnapshotManager 経由で workspace.json に永続化される。
enum RecommendStore {
    /// インメモリキャッシュ
    private static var cache: [String: SceneConfig] = [:]

    /// 全データをセットする（apply からの復元用）
    static func setAll(_ data: [String: SceneConfig]) {
        cache = data
    }

    /// 全データを返す（save 時の取得用）
    static func getAll() -> [String: SceneConfig] {
        cache
    }

    /// 指定 Scene の設定を取得する
    static func config(for scene: String) -> SceneConfig? {
        cache[scene]
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
        var conf = cache[scene] ?? SceneConfig()
        conf.prompts = prompts
        cache[scene] = conf
    }

    /// 指定 Scene のデフォルトコンパニオンを保存する
    static func saveDefaultCompanion(scene: String, index: Int) {
        var conf = cache[scene] ?? SceneConfig()
        conf.defaultCompanionIndex = index
        cache[scene] = conf
    }

    /// Scene に対するプロンプトを解決する（永続化 > デフォルト > 空）
    static func resolve(scene: String?, defaults: [String]) -> [String] {
        if let scene, let saved = prompts(for: scene), !saved.isEmpty {
            return saved
        }
        return defaults
    }
}
