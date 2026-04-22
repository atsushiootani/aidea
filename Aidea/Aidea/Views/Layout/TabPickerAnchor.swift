//
//  TabPickerAnchor.swift
//  Aidea
//

import AppKit
import Observation

/// Cmd+T のツール選択メニューを「+」ボタンの右下に出すためのアンカー管理。
/// 各 PaneView が GeometryReader 経由で「+」ボタンの window 座標 frame を登録し、
/// AideaApp 側から screen 座標を問い合わせ可能にする。
///
/// NSViewRepresentable + `.background` 方式は SwiftUI Menu と組み合わせると
/// Auto Layout の updateConstraints で NSException を投げて落ちたため、
/// SwiftUI 内で完結する frame ベース方式を採用している。
@Observable
final class TabPickerAnchor {
    /// paneID → SwiftUI `.global` 座標系での「+」ボタン frame
    private var frames: [UUID: CGRect] = [:]

    /// AddButtonAnchorReader から呼ばれる frame 更新。上書き許容。
    func register(paneID: UUID, frame: CGRect) {
        frames[paneID] = frame
    }

    /// PaneView が消える際の解除。呼び忘れても致命的ではない (古い frame は使われないだけ)。
    func unregister(paneID: UUID) {
        frames.removeValue(forKey: paneID)
    }

    /// 指定 Pane の「+」ボタンの右下を screen 座標で返す。
    /// メインウィンドウ未取得や frame 未登録の場合は nil。
    func bottomRightScreenPoint(for paneID: UUID) -> NSPoint? {
        guard let frame = frames[paneID], let window = NSApp.mainWindow else { return nil }
        // SwiftUI .global は左上原点・window 内座標。AppKit window は左下原点なので Y 軸を反転する。
        let contentHeight = window.contentLayoutRect.height
        let windowPoint = NSPoint(x: frame.maxX, y: contentHeight - frame.maxY)
        let screenRect = window.convertToScreen(NSRect(origin: windowPoint, size: .zero))
        // Menu の background frame は + Image の vertical padding (3pt) や NSMenu の内部余白を含むため、
        // 画面上で上方向に少し寄せて「+」アイコンとメニュー上端をピッタリくっつける。
        return NSPoint(x: screenRect.origin.x, y: screenRect.origin.y + Self.popupYOffset)
    }

    /// 「+」アイコンとメニュー上端をくっつけるための上方向オフセット (AppKit 座標系: 正で上)
    private static let popupYOffset: CGFloat = 12
}
