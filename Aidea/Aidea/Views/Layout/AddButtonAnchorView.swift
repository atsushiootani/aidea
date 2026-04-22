//
//  AddButtonAnchorView.swift
//  Aidea
//

import SwiftUI

/// PaneView の「+」ボタンの背後に GeometryReader を仕込み、
/// global 座標系での frame を TabPickerAnchor に伝える純 SwiftUI View。
/// (NSViewRepresentable 方式は Menu の Auto Layout と衝突して落ちたため不採用)
struct AddButtonAnchorView: View {
    let paneID: UUID
    let anchor: TabPickerAnchor

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { anchor.register(paneID: paneID, frame: proxy.frame(in: .global)) }
                .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                    anchor.register(paneID: paneID, frame: newFrame)
                }
        }
    }
}
