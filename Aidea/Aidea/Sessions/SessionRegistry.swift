//
//  SessionRegistry.swift
//  Aidea
//

import SwiftUI
import AppKit
import Observation

/// Session 実体のライフサイクルを管理するレジストリ。
/// SessionID をキーに SessionState を保持し、対応する SwiftUI View を生成する。
/// "アクティブな Session" とレイアウトへの参照もここで集中管理する。
@Observable
final class SessionRegistry {
    /// SessionID -> SessionState の保持 (型消去)
    /// SwiftUI の update サイクル中に mutate するとクラッシュするため、
    /// Observation 追跡から除外する (キャッシュ用途なのでビューが再評価を必要としない)
    @ObservationIgnored private var states: [SessionID: any SessionState] = [:]
    /// 共有のワークスペース状態 (各 SessionState から参照される)
    let workspace: WorkspaceState
    /// Tab のレイアウト設定 (新しい Preview タブ作成などで参照)
    let layout: LayoutConfig
    /// 現在ウィンドウ全体でアクティブな Session の ID (常に 1 つ)
    var activeSessionID: SessionID? {
        didSet {
            guard let id = activeSessionID, id != oldValue else { return }
            // 履歴の末尾が最新。重複は詰めて追加。最大 50 件保持
            activeHistory.removeAll { $0 == id }
            activeHistory.append(id)
            if activeHistory.count > 50 {
                activeHistory.removeFirst(activeHistory.count - 50)
            }
        }
    }
    /// activeSessionID の変更履歴 (末尾が最新)。openPreview が参照先ペインを選ぶのに使う。
    private(set) var activeHistory: [SessionID] = []

    init(workspace: WorkspaceState, layout: LayoutConfig) {
        self.workspace = workspace
        self.layout = layout
    }

    /// 指定 ID の状態を取得 (なければ生成して保持)
    func state(for id: SessionID) -> any SessionState {
        if let existing = states[id] { return existing }
        let created = makeState(for: id.tool)
        states[id] = created
        return created
    }

    /// 指定 ID の状態を取得する。未生成なら nil を返す (副作用なし)。
    /// 永続化時に "既に使われている Session だけ" を保存するのに使う。
    func peekState(for id: SessionID) -> (any SessionState)? {
        return states[id]
    }

    /// アクティブタブ切替時に First Responder にしたい NSView を返す。
    /// NSView を直接保持する Session (filer / terminal / web) だけ対応。
    /// SwiftUI 系 Session は nil を返す (将来 NSHostingView 経由で対応予定)。
    func focusableView(for id: SessionID) -> NSView? {
        guard let state = states[id] else { return nil }
        switch id.tool {
        case .filer:
            return (state as? FilerSessionState)?.controller.outlineView
        case .terminal:
            return (state as? TerminalSessionState)?.terminalView
        case .web:
            return (state as? WebSessionState)?.webView
        default:
            return nil
        }
    }

    /// Filer や Kit のダブルクリック等から呼ばれる: 新しい Preview Tab を
    /// 「呼び出し元 Session のペイン以外で、履歴上もっとも新しい Session のペイン」に作成する。
    ///
    /// 呼び出し元 Session は `activeSessionID` から取得される。呼び出し側は openPreview の前に
    /// 自身を activeSessionID に設定しておくこと。
    func openPreview(for url: URL, title: String? = nil) {
        // 既に同じファイルを開いている Preview があれば、そのタブをアクティブ化するだけ
        // (タイトルが指定されていれば既存ステートのタイトルも更新する)
        for pane in layout.allPanes {
            for (index, id) in pane.tabs.enumerated() where id.tool == .preview {
                if let preview = states[id] as? PreviewSessionState, preview.url == url {
                    if let title = title { preview.title = title }
                    pane.activeIndex = index
                    activeSessionID = id
                    return
                }
            }
        }

        // 呼び出し元 Session が属するペイン (回避対象)
        let callerPane: Pane? = activeSessionID.flatMap { id in
            layout.allPanes.first { $0.tabs.contains(id) }
        }
        // 履歴を新しい順にたどり、callerPane 以外に属していた最新 Session を探す
        var targetPane: Pane?
        for id in activeHistory.reversed() {
            if let pane = layout.allPanes.first(where: { $0.tabs.contains(id) }),
               pane !== callerPane {
                targetPane = pane
                break
            }
        }
        // フォールバック: callerPane 以外の最初のペイン
        if targetPane == nil {
            targetPane = layout.allPanes.first { $0 !== callerPane }
        }
        guard let pane = targetPane else { return }

        let instance = layout.nextSessionInstance(of: .preview)
        let id = SessionID(.preview, instance: instance)
        let state = self.state(for: id) as! PreviewSessionState
        state.url = url
        state.title = title
        pane.tabs.append(id)
        pane.activeIndex = pane.tabs.count - 1
        activeSessionID = id
    }

    /// Preview 内リンククリックなどから呼ばれる: 新しい Preview Tab を
    /// **呼び出し元 (activeSessionID) と同じペイン** の現在タブの右隣に挿入する。
    /// 同じ URL の Preview が既に存在する場合はそれをアクティブ化するだけ。
    /// 呼び出し元ペインが見つからない場合は通常の `openPreview` にフォールバックする。
    func openPreviewAsSibling(for url: URL, title: String? = nil) {
        // dedupe: 同じ URL を表示中の Preview があればアクティブ化
        for pane in layout.allPanes {
            for (index, id) in pane.tabs.enumerated() where id.tool == .preview {
                if let preview = states[id] as? PreviewSessionState, preview.url == url {
                    if let title = title { preview.title = title }
                    pane.activeIndex = index
                    activeSessionID = id
                    return
                }
            }
        }
        // 呼び出し元ペインの特定
        guard let callerID = activeSessionID,
              let pane = layout.allPanes.first(where: { $0.tabs.contains(callerID) }),
              let currentIndex = pane.tabs.firstIndex(of: callerID) else {
            openPreview(for: url, title: title)
            return
        }
        // 新しい Preview を挿入
        let instance = layout.nextSessionInstance(of: .preview)
        let newID = SessionID(.preview, instance: instance)
        let state = self.state(for: newID) as! PreviewSessionState
        state.url = url
        state.title = title
        let insertIndex = currentIndex + 1
        pane.tabs.insert(newID, at: insertIndex)
        pane.activeIndex = insertIndex
        activeSessionID = newID
    }

    /// ファイル/ディレクトリが削除されたとき、そのファイルを表示していた
    /// Preview タブをすべて閉じる。ディレクトリ削除時は配下のファイルも対象。
    func closePreviewsForDeleted(_ deleted: URL, isDirectory: Bool) {
        let deletedPath = deleted.path
        for pane in layout.allPanes {
            var indicesToRemove: [Int] = []
            for (idx, id) in pane.tabs.enumerated() where id.tool == .preview {
                guard let state = states[id] as? PreviewSessionState,
                      let url = state.url else { continue }
                let path = url.path
                let matches: Bool
                if isDirectory {
                    matches = (path == deletedPath) || path.hasPrefix(deletedPath + "/")
                } else {
                    matches = (path == deletedPath)
                }
                if matches {
                    indicesToRemove.append(idx)
                }
            }
            // 後ろから削除することでインデックスのずれを防ぐ
            for idx in indicesToRemove.reversed() {
                pane.tabs.remove(at: idx)
            }
            if pane.tabs.isEmpty {
                pane.activeIndex = 0
            } else if pane.activeIndex >= pane.tabs.count {
                pane.activeIndex = pane.tabs.count - 1
            }
        }
        // アクティブ Session が閉じられていたらフォールバック
        if let active = activeSessionID,
           !layout.allPanes.contains(where: { $0.tabs.contains(active) }) {
            activeSessionID = layout.allPanes
                .compactMap { $0.activeSessionID }
                .first
        }
    }

    /// Tab のドラッグ&ドロップ: 指定 Session を移動する (同ペイン内の並び替えも対応)。
    /// - Parameters:
    ///   - id: 移動対象の SessionID
    ///   - target: 移動先のペイン
    ///   - index: 移動先ペイン内の挿入位置 (末尾に追加したいなら tabs.count を渡す)
    func moveSession(_ id: SessionID, toPane target: Pane, atIndex index: Int) {
        guard let sourcePane = layout.allPanes.first(where: { $0.tabs.contains(id) }),
              let sourceIndex = sourcePane.tabs.firstIndex(of: id) else {
            return
        }
        if sourcePane === target {
            // 同じ Slot への no-op (自身の直前/直後の Slot にドロップしても位置が変わらない)
            if index == sourceIndex || index == sourceIndex + 1 {
                activeSessionID = id
                return
            }
            // 同一ペイン内での並び替え: 削除後に挿入位置を補正する
            sourcePane.tabs.remove(at: sourceIndex)
            let adjusted = sourceIndex < index ? index - 1 : index
            let clamped = max(0, min(adjusted, sourcePane.tabs.count))
            sourcePane.tabs.insert(id, at: clamped)
            sourcePane.activeIndex = clamped
        } else {
            // ペイン間の移動
            sourcePane.tabs.remove(at: sourceIndex)
            if sourcePane.tabs.isEmpty {
                sourcePane.activeIndex = 0
            } else if sourcePane.activeIndex >= sourcePane.tabs.count {
                sourcePane.activeIndex = sourcePane.tabs.count - 1
            }
            let clamped = max(0, min(index, target.tabs.count))
            target.tabs.insert(id, at: clamped)
            target.activeIndex = clamped
        }
        activeSessionID = id
    }

    /// tool に応じた SessionState インスタンスを生成する
    private func makeState(for tool: Tool) -> any SessionState {
        switch tool {
        case .filer:
            let state = FilerSessionState(workspace: workspace)
            state.registry = self
            return state
        case .kit:      return KitSessionState(workspace: workspace)
        case .terminal: return TerminalSessionState(workspace: workspace)
        case .web:      return WebSessionState()
        case .preview:  return PreviewSessionState()
        }
    }

    /// SessionID に対応する SwiftUI View を返す
    @ViewBuilder
    func view(for id: SessionID) -> some View {
        let state = state(for: id)
        switch id.tool {
        case .filer:    FilerSessionView(state: state as! FilerSessionState)
        case .kit:      KitSessionView(state: state as! KitSessionState, sessionID: id)
        case .terminal: TerminalSessionView(state: state as! TerminalSessionState)
        case .web:      WebSessionView(state: state as! WebSessionState)
        case .preview:  PreviewSessionView(state: state as! PreviewSessionState, sessionID: id)
        }
    }
}
