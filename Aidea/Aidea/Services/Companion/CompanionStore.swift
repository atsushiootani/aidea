//
//  CompanionStore.swift
//  Aidea
//

import Foundation
import Observation

/// コンパニオン (9 個固定 / index 0...8) と Claude セッション紐付けを管理する。
/// 紐付き状態は `CompanionConfig.sessionID` に統合されている (別マップは持たない)。
/// データは WorkspaceSnapshotManager 経由で workspace.json v7 に永続化される。
@Observable
final class CompanionStore {
    /// 必ず 9 要素 (index 0...8)。空にしたり追加・削除はしない
    var companions: [CompanionConfig] = []

    /// 指定 index のコンパニオン設定を更新する (sessionID を含む全フィールド差し替え)
    func update(_ companion: CompanionConfig) {
        guard companion.index >= 0, companion.index < companions.count else { return }
        companions[companion.index] = companion
    }

    /// コンパニオンが起動中かどうか (sessionID != nil)
    func isActive(_ index: Int) -> Bool {
        guard index >= 0, index < companions.count else { return false }
        return companions[index].sessionID != nil
    }

    /// コンパニオンと Claude セッションを紐付ける
    func bind(index: Int, sessionID: SessionID) {
        guard index >= 0, index < companions.count else { return }
        companions[index].sessionID = sessionID
    }

    /// コンパニオンの紐付けを解除する
    func unbind(index: Int) {
        guard index >= 0, index < companions.count else { return }
        companions[index].sessionID = nil
    }

    /// SessionID から該当コンパニオンの紐付けを解除する（セッション終了時用）
    func unbindSession(_ sessionID: SessionID) {
        for i in companions.indices where companions[i].sessionID == sessionID {
            companions[i].sessionID = nil
        }
    }

    /// SessionID に紐付くコンパニオン名を返す（タブ表示用）
    func companionName(for sessionID: SessionID) -> String? {
        companions.first { $0.sessionID == sessionID }?.name
    }

    /// SessionID に紐付くコンパニオン設定を返す（アイコン取得など複数フィールドが必要なときに）
    func companion(for sessionID: SessionID) -> CompanionConfig? {
        companions.first { $0.sessionID == sessionID }
    }

    /// アイコンインデックスに対応するコンパニオン設定を返す (9 個固定なので必ず存在)
    func companion(forIndex index: Int) -> CompanionConfig {
        companions[index]
    }
}
