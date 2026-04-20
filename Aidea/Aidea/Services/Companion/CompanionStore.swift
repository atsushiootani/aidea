//
//  CompanionStore.swift
//  Aidea
//

import Foundation
import Observation

/// コンパニオン設定とセッション紐付けを管理する。
/// データは WorkspaceSnapshotManager 経由で workspace.json に永続化される。
@Observable
final class CompanionStore {
    var companions: [CompanionConfig] = []
    /// コンパニオン ID → 紐付けられた SessionID のマッピング
    var activeSessionMap: [UUID: SessionID] = [:]

    /// コンパニオンを追加する
    func add(_ companion: CompanionConfig) {
        companions.append(companion)
    }

    /// コンパニオンを更新する
    func update(_ companion: CompanionConfig) {
        if let index = companions.firstIndex(where: { $0.id == companion.id }) {
            companions[index] = companion
        }
    }

    /// コンパニオンを削除する
    func remove(_ companion: CompanionConfig) {
        companions.removeAll { $0.id == companion.id }
        activeSessionMap.removeValue(forKey: companion.id)
    }

    /// コンパニオンが起動中かどうか
    func isActive(_ companionID: UUID) -> Bool {
        activeSessionMap[companionID] != nil
    }

    /// コンパニオンと Claude セッションを紐付ける
    func bind(companionID: UUID, sessionID: SessionID) {
        activeSessionMap[companionID] = sessionID
    }

    /// コンパニオンの紐付けを解除する
    func unbind(companionID: UUID) {
        activeSessionMap.removeValue(forKey: companionID)
    }

    /// SessionID からコンパニオンの紐付けを解除する（セッション終了時用）
    func unbindSession(_ sessionID: SessionID) {
        activeSessionMap = activeSessionMap.filter { $0.value != sessionID }
    }

    /// SessionID に紐付くコンパニオン名を返す（タブ表示用）
    func companionName(for sessionID: SessionID) -> String? {
        guard let companionID = activeSessionMap.first(where: { $0.value == sessionID })?.key else { return nil }
        return companions.first { $0.id == companionID }?.name
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
    }
}
