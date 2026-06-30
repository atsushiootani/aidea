//
//  VideoPreview.swift
//  Aidea
//

import SwiftUI
import AVKit

struct VideoPreview: View {
    let url: URL
    /// 手動リロード要求カウンタ (issue #241)。変化したらプレーヤーを作り直す。
    var reloadToken: Int = 0
    @State private var player: AVPlayer? = nil

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: url)
            }
            .onDisappear {
                player?.pause()
            }
            .onChange(of: reloadToken) { _, _ in
                player?.pause()
                player = AVPlayer(url: url)
            }
    }
}
