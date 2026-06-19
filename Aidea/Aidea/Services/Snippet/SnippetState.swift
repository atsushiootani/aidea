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
        /// 特定のターミナルセッション ID を指定
        case session(SessionID)
        /// 常に新規ターミナルタブを開く
        case new
    }

    func start(projectRoot: URL, dispatch: @escaping (String, DispatchTarget) -> Void) {
        let store = SnippetStore(projectRoot: projectRoot)
        self.store = store
        self.dispatch = dispatch
        self.snippets = store.loadConfig().validSnippets()
    }

    func run(snippetID: String, target: DispatchTarget) {
        guard let snippet = snippets.first(where: { $0.id == snippetID }),
              snippet.isEnabled else { return }
        dispatch?(snippet.command, target)
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
