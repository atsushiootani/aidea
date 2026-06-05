//
//  InstanceActivationChannel.swift
//  Aidea
//

import Foundation
import AppKit

/// 同一リポジトリの二重起動時に、既存プロセスを前面化するためのプロセス間通知チャネル。
/// lock のトークンを名前空間にした DistributedNotification を使い、宛先プロセスだけが反応する。
/// トークンで宛先を絞ることで、別リポジトリを開いている無関係なプロセスを前面化しない。
/// 詳細: docs/specs/window/multi-instance.md / ADR 0030
enum InstanceActivationChannel {
    /// token から前面化通知の名前を作る
    private static func notificationName(for token: String) -> Notification.Name {
        Notification.Name("jp.ruri.aidea.activate.\(token)")
    }

    /// 既存プロセスに前面化を要求する (新プロセス側が、起動を中止する直前に呼ぶ)。
    /// deliverImmediately で、呼び出し元がすぐ終了しても配送されるようにする。
    static func requestActivation(token: String) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName(for: token),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    /// 自プロセスの token 宛の前面化要求を購読する (既存プロセス側が起動後に呼ぶ)。
    /// 受信時に handler を main キューで呼ぶ。返り値の observer は購読解除に使う。
    @discardableResult
    static func observeActivation(token: String, handler: @escaping () -> Void) -> NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(
            forName: notificationName(for: token),
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
    }

    /// 前面化要求の購読を解除する
    static func removeObserver(_ observer: NSObjectProtocol) {
        DistributedNotificationCenter.default().removeObserver(observer)
    }
}
