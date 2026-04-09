//
//  FileWatcher.swift
//  Aidea
//

import Foundation
import CoreServices

/// FSEventStream の Swift ラッパ。指定ディレクトリ配下の変更を監視する。
/// 1 インスタンス = 1 ストリーム。`start` で開始、`stop` で停止。
final class FileWatcher {
    private var stream: FSEventStreamRef?
    /// 変更通知のコールバック。引数は変更があったパスの集合。
    private var onChange: ((Set<String>) -> Void)?

    /// 監視を開始する。既に動いていれば一旦停止してから再開する。
    func start(path: String, onChange: @escaping (Set<String>) -> Void) {
        stop()
        self.onChange = onChange

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = Array(UnsafeBufferPointer(
                start: eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self),
                count: numEvents
            )).compactMap { String(cString: $0) }
            DispatchQueue.main.async {
                watcher.onChange?(Set(paths))
            }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagFileEvents)
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    /// 監視を停止してストリームを解放する
    func stop() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        self.onChange = nil
    }

    deinit {
        stop()
    }
}
