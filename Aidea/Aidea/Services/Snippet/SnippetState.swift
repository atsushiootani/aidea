//
//  SnippetState.swift
//  Aidea
//

import Foundation
import Observation

/// コードスニペットの状態管理。SnippetStore で config をロードし、
/// dispatch クロージャ経由でターミナルセッションへコマンドを送る。
/// Engine / タイマー不要のシンプルな構造 (SchedulerState よりずっと軽い)。
/// docs/specs/widgets/snippets.md 参照。
@MainActor
@Observable
final class SnippetState {
    private(set) var snippets: [SnippetConfig.Snippet] = []
    var isPopoverPresented: Bool = false

    @ObservationIgnored
    private var store: SnippetStore?
    /// dispatch: (command, target) → Void。AideaApp が注入する。
    @ObservationIgnored
    private var dispatch: ((String, DispatchTarget) -> Void)?

    /// スニペット実行時の送信先。
    enum DispatchTarget {
        /// アクティブなターミナルがあればそこへ、なければ自動で新規タブ
        case active
        /// 特定のターミナルセッション ID を指定 (実行メニューでの明示選択用)
        case session(SessionID)
        /// タブ名で指定 (無ければその名前で新規作成。スケジューラと共通の解決)
        case tab(title: String)
        /// 常に新規ターミナルタブを開く
        case new
    }

    func start(projectRoot: URL, dispatch: @escaping (String, DispatchTarget) -> Void) {
        let store = SnippetStore(projectRoot: projectRoot)
        self.store = store
        self.dispatch = dispatch
        self.snippets = store.loadConfig().validSnippets()
    }

    /// 明示的に送信先を指定して実行する (実行メニューでの選択用)。
    func run(snippetID: String, target: DispatchTarget) {
        guard let snippet = snippets.first(where: { $0.id == snippetID }) else { return }
        dispatch?(snippet.command, target)
    }

    /// スニペットの既定送信先 (`destination`) へ実行する (主ボタン用)。
    /// destination 省略時はアクティブ端末。
    func run(snippetID: String) {
        guard let snippet = snippets.first(where: { $0.id == snippetID }) else { return }
        dispatch?(snippet.command, Self.dispatchTarget(for: snippet.destination))
    }

    /// 保存された Destination を実行時の DispatchTarget へ変換する。nil = アクティブ端末。
    static func dispatchTarget(for destination: SnippetConfig.Destination?) -> DispatchTarget {
        switch destination {
        case .none: return .active
        case .tab(let title): return .tab(title: title)
        case .new: return .new
        }
    }

    func addSnippet(_ snippet: SnippetConfig.Snippet) {
        guard let store else { return }
        var config = store.loadConfig()
        config.snippets.append(snippet)
        persist(config)
    }

    func updateSnippet(_ snippet: SnippetConfig.Snippet) {
        guard let store else { return }
        var config = store.loadConfig()
        if let idx = config.snippets.firstIndex(where: { $0.id == snippet.id }) {
            config.snippets[idx] = snippet
        } else {
            config.snippets.append(snippet)
        }
        persist(config)
    }

    func deleteSnippet(snippetID: String) {
        guard let store else { return }
        var config = store.loadConfig()
        config.snippets.removeAll { $0.id == snippetID }
        persist(config)
    }

    private func persist(_ config: SnippetConfig) {
        guard let store else { return }
        store.saveConfig(config)
        snippets = config.validSnippets()
    }

    static func newID() -> String {
        "snip-" + UUID().uuidString.prefix(8).lowercased()
    }
}
