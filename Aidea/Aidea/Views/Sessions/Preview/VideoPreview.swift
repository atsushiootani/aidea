//
//  VideoPreview.swift
//  Aidea
//

import SwiftUI
import AVKit

struct VideoPreview: View {
    let url: URL
    @State private var player: AVPlayer? = nil

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: url)
            }
            .onDisappear {
                player?.pause()
            }
    }
}
