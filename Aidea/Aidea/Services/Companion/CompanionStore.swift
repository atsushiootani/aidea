//
//  CompanionStore.swift
//  Aidea
//

import Foundation
import Observation

/// コンパニオン設定の読み書きと、コンパニオン ↔ Claude セッションの紐付けを管理する。
/// 設定と紐付けは `.aidea/companions.json` に永続化する。
@Observable
final class CompanionStore {
    var companions: [CompanionConfig] = []
    /// コンパニオン ID → 紐付けられた SessionID のマッピング
    var activeSessionMap: [UUID: SessionID] = [:]

    private var projectRoot: URL?
    private var configURL: URL? {
        projectRoot?.appending(path: ".aidea/companions.json")
    }

    /// 永続化用のデータ構造
    private struct StoreData: Codable {
        var companions: [CompanionConfig]
        var bindings: [Binding]

        struct Binding: Codable {
            var companionID: UUID
            var sessionID: SessionID
        }
    }

    /// プロジェクトルートを設定し、設定を読み込む
    func load(projectRoot: URL) {
        self.projectRoot = projectRoot
        guard let url = configURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return }

        // 新フォーマット (StoreData) を試す
        if let storeData = try? JSONDecoder().decode(StoreData.self, from: data) {
            companions = storeData.companions
            activeSessionMap = [:]
            for binding in storeData.bindings {
                activeSessionMap[binding.companionID] = binding.sessionID
            }
            return
        }
        // 旧フォーマット ([CompanionConfig]) からのマイグレーション
        if let loaded = try? JSONDecoder().decode([CompanionConfig].self, from: data) {
            companions = loaded
            activeSessionMap = [:]
        }
    }

    /// 設定と紐付けをファイルに保存する
    func save() {
        guard let url = configURL else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let bindings = activeSessionMap.map { StoreData.Binding(companionID: $0.key, sessionID: $0.value) }
        let storeData = StoreData(companions: companions, bindings: bindings)
        if let data = try? JSONEncoder().encode(storeData) {
            try? data.write(to: url)
        }
    }

    /// コンパニオンを追加する
    func add(_ companion: CompanionConfig) {
        companions.append(companion)
        save()
    }

    /// コンパニオンを更新する
    func update(_ companion: CompanionConfig) {
        if let index = companions.firstIndex(where: { $0.id == companion.id }) {
            companions[index] = companion
            save()
        }
    }

    /// コンパニオンを削除する
    func remove(_ companion: CompanionConfig) {
        companions.removeAll { $0.id == companion.id }
        activeSessionMap.removeValue(forKey: companion.id)
        save()
    }

    /// コンパニオンが起動中かどうか
    func isActive(_ companionID: UUID) -> Bool {
        activeSessionMap[companionID] != nil
    }

    /// コンパニオンと Claude セッションを紐付ける
    func bind(companionID: UUID, sessionID: SessionID) {
        activeSessionMap[companionID] = sessionID
        save()
    }

    /// コンパニオンの紐付けを解除する
    func unbind(companionID: UUID) {
        activeSessionMap.removeValue(forKey: companionID)
        save()
    }

    /// SessionID からコンパニオンの紐付けを解除する（セッション終了時用）
    func unbindSession(_ sessionID: SessionID) {
        activeSessionMap = activeSessionMap.filter { $0.value != sessionID }
        save()
    }

    /// SessionID に紐付くコンパニオン名を返す（タブ表示用）
    func companionName(for sessionID: SessionID) -> String? {
        guard let companionID = activeSessionMap.first(where: { $0.value == sessionID })?.key else { return nil }
        return companions.first { $0.id == companionID }?.name
    }

    /// 自動起動対象のコンパニオン一覧
    var autoLaunchCompanions: [CompanionConfig] {
        companions.filter { $0.autoLaunch }
    }

    /// アイコンインデックスに対応するコンパニオン設定を返す（未登録なら nil）
    func companion(forIndex index: Int) -> CompanionConfig? {
        let icon = CompanionIconPresets.imageIcons[index]
        return companions.first { $0.icon == icon }
    }

    /// アイコンインデックスからデフォルト設定のコンパニオンを生成する（まだ store に未登録）
    func createDefault(forIndex index: Int) -> CompanionConfig {
        let icon = CompanionIconPresets.imageIcons[index]
        return CompanionConfig(
            name: "Companion \(index + 1)",
            icon: icon,
            initialPrompt: ".aidea/claude/aidea.md と .aidea/claude/speech.md を読んで従ってね"
        )
    }

    /// 追加または更新する
    func upsert(_ companion: CompanionConfig) {
        if let index = companions.firstIndex(where: { $0.id == companion.id }) {
            companions[index] = companion
        } else {
            companions.append(companion)
        }
        save()
    }
}
