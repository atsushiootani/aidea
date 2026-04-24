//
//  ClaudeSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import Observation
import SwiftTerm

/// Claude Session の内部状態。
/// Terminal と同じ PTY を起動した上で、claude コマンドと Backchannel 指示を自動送信する。
@Observable
final class ClaudeSessionState: SessionState, FocusBridgeOwner {
    let workspace: WorkspaceState
    /// フォーカス契約 C1/C2/C3 を担う非永続ヘルパ (仕様は focus-contract.md)
    let focusBridge = SessionFocusBridge()
    @ObservationIgnored private var cached: PersistentTerminalView?

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// SessionRegistry への弱参照 (クリック時のアクティブ化用)
    weak var registry: SessionRegistry?
    /// 紐付けられたコンパニオンの起動時送信文字列。
    /// nil または空のときは起動時に何も送信しない。
    /// v8 以降は `CompanionInstructions.loadCommand(for:)` が生成する固定パターン文字列
    /// (`.aidea/claude/companions/<index>/instructions.md を読んで従ってね`) で、
    /// Claude が `Read` ツールで instructions.md を読み込む経路に変わった (ADR 0022)。
    var companionPrompt: String?
    /// 紐付く Companion の index (0…8)。Scene 識別子 `claude:<index>` の解決および
    /// `companionPrompt` 文字列の生成 (`CompanionInstructions.loadCommand(for:)`) に使う。
    /// `companionPrompt` と同じ経路で createSession / スナップショット復元時にセットされる。
    var companionIndex: Int?

    /// PTY 起動 + claude コマンド送信 + companionPrompt 送信/Enter が完了し、
    /// Frontchannel (`sendMessage`) からの入力を受け付け可能になったか。
    /// `autoStartClaude` のシーケンスが終わるタイミングで true に遷移する。
    /// 呼び出し側は `sendMessageWhenReady` を使えば ready まで自動で待機する。
    var isReady: Bool = false

    /// Claude が作業中 (= PTY 出力が続いている) かどうか。CompanionView がアイコン表情切替で参照する (issue #45)。
    /// 判定ロジックは `noteTerminalOutput` のデバウンスに集約され、外部書き換えは禁止。
    private(set) var isBusy: Bool = false

    /// この Companion の speech が VOICEVOX で再生中かどうか (issue #45)。
    /// 状態源は `SpeechQueue.currentlySpeakingIndex` で、`companionIndex` と一致する間だけ true。
    /// ClaudeSessionState 側を facade として返すことで、CompanionView は isBusy と対称に read できる。
    var isSpeaking: Bool {
        guard let index = companionIndex else { return false }
        return speechQueue?.currentlySpeakingIndex == index
    }

    /// 読み上げ中判定 (`isSpeaking`) の参照先。AideaApp / CompanionView / WorkspaceSnapshotManager が
    /// Claude セッション生成・復元時に注入する。SpeechQueue 自身は @Observable なので、
    /// `isSpeaking` を読むスコープに tracking が伝播する。
    @ObservationIgnored weak var speechQueue: SpeechQueue?

    /// busy 静止判定の閾値。`claude` CLI が tool 実行中やストリーミング中に
    /// 細切れに出力することを踏まえた体感値 (詳細は tools/claude.md#実行中判定-isbusy-issue-45)
    @ObservationIgnored private static let busyDebounceInterval: TimeInterval = 0.5

    /// 出力が途切れて `busyDebounceInterval` 経過したら busy=false に戻すためのタイマー
    @ObservationIgnored private var busyDebounceTimer: Timer?

    /// 保留中の送信メッセージ (isReady=false の間に `sendMessageWhenReady` で積まれる)
    @ObservationIgnored private var pendingMessages: [String] = []

    /// Frontchannel: Claude セッションにメッセージを送信する。ready 判定は行わないため
    /// 起動直後に呼ぶと TUI 初期化中で取りこぼされる可能性がある。Claude 起動シーケンス完了を
    /// 待ってから送りたい場合は `sendMessageWhenReady` を使う。
    func sendMessage(_ message: String) {
        terminalView.send(txt: message + "\r")
        // 出力が返る前に即座に「実行中」表示へ (issue #45)。PTY 出力が続く間は
        // noteTerminalOutput のデバウンスで isBusy=true が維持される。
        noteTerminalOutput()
    }

    /// Claude 起動シーケンス完了 (isReady=true) を待ってから `sendMessage` を呼ぶ。
    /// - 既に ready なら即送信
    /// - まだ準備中なら `pendingMessages` に積み、`autoStartClaude` の最終ステップで flush される
    /// 呼び出し側は固定 asyncAfter で待つ必要がなくなり、Claude 側 TUI 初期化時間の変動にも追従できる。
    func sendMessageWhenReady(_ message: String) {
        if isReady {
            sendMessage(message)
        } else {
            pendingMessages.append(message)
        }
    }

    /// レコメンドモード用の Scene 識別子を返す。Companion ごとに Scene を分ける。
    /// 仕様: docs/specs/sessions/claude.md#scene-とレコメンドプロンプト
    func currentScene() -> String? {
        companionIndex.map { "claude:\($0)" }
    }

    /// 契約 C1: bridge 経由で terminalView に firstResponder を移す。
    /// NSView 参照の登録は View 側 (ClaudeSessionView.makeNSView) で行う。
    /// cached が lazy 生成のため pending パターンで自動解消される。
    func didBecomeActive(session: Session) {
        focusBridge.activate()
    }

    /// 契約 C2: bridge 経由で自分配下の firstResponder を解放する。
    func didResignActive(session: Session) {
        focusBridge.deactivate()
    }

    /// View 側で参照する PersistentTerminalView (初回のみ PTY を起動)
    var terminalView: PersistentTerminalView {
        if let cached = cached { return cached }
        let terminal = PersistentTerminalView(frame: .zero)
        let reg = registry
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak terminal, weak self] event in
            if let tv = terminal,
               let reg = self?.registry,
               let clickedView = event.window?.contentView?.hitTest(event.locationInWindow),
               clickedView.isDescendant(of: tv) {
                for pane in reg.layout.allPanes {
                    for id in pane.tabs where id.tool == .claude {
                        if let s = reg.session(for: id),
                           let state = s.state as? ClaudeSessionState,
                           state === self {
                            reg.activateSession(id)
                            break
                        }
                    }
                }
            }
            return event
        }
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("SHELL=/bin/zsh")
        let path = workspace.projectRoot?.path
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        let command = "cd '\(escaped)' && exec zsh -l"
        terminal.startProcess(
            executable: "/bin/zsh",
            args: ["-c", command],
            environment: env
        )
        terminal.installLinkGuard(isClaudeSession: true)
        // PTY 出力で busy 状態追跡する (issue #45)。rangeChanged 経由で呼ばれる。
        // SwiftTerm の `notifyUpdateChanges` はデフォルト false で、true にしないと
        // `rangeChanged` デリゲートが一切発火しない。Claude セッションだけ有効化する。
        terminal.notifyUpdateChanges = true
        terminal.onTerminalOutput = { [weak self] in
            self?.noteTerminalOutput()
        }
        cached = terminal
        autoStartClaude(terminal: terminal)
        return terminal
    }

    /// PTY からの出力を観測したときに呼ぶ。isBusy=true にし、`busyDebounceInterval` 秒の
    /// 静止タイマーをセットする。既存タイマーは invalidate してリセットするので、
    /// 出力が続く限り静止タイマーは発火せず、出力が止まった瞬間から 0.5s で false に落ちる。
    ///
    /// ⚠ `isBusy` の書き込みは `DispatchQueue.main.async` で必ず次の runloop tick に遅延させる。
    /// 呼び出し元 (SwiftTerm の `rangeChanged` デリゲート / Timer.common) は SwiftUI の
    /// view update サイクル中に同期発火し得るため、その中で `@Observable` プロパティを書くと
    /// `AttributeGraph: cycle detected` のログが大量に出てビューが描画されなくなる。
    /// (詳細は [docs/conventions/swift.md#observable-のアクセスパターン-attributegraph-cycle-対策])
    private func noteTerminalOutput() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.isBusy { self.isBusy = true }
            self.busyDebounceTimer?.invalidate()
            let timer = Timer(timeInterval: Self.busyDebounceInterval, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if self.isBusy { self.isBusy = false }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.busyDebounceTimer = timer
        }
    }

    /// 対話シェル準備完了後に claude を起動し、`companionPrompt` を送る。
    /// `companionPrompt` は v8 以降 `.aidea/claude/companions/<index>/instructions.md を読んで従ってね` の
    /// 固定パターンで、Claude が Read ツールで本体を取りに行く (ADR 0022)。
    /// send() は PTY へのキー入力なので、ユーザーが手で打ったのと同等。
    /// (ADR 0008 の非対話シェル問題を回避)
    /// 起動シーケンス完了時に `isReady = true` にし、`pendingMessages` を flush する。
    private func autoStartClaude(terminal: PersistentTerminalView) {
        let prompt = companionPrompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            terminal.send(txt: "claude\n")
        }
        guard let prompt, !prompt.isEmpty else {
            // companionPrompt が無い場合は claude コマンド送信後すぐ ready とみなす。
            // 0.3s の余裕は PTY が claude 起動 (TUI 描画開始) を完了する目安。
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
                self?.markReady()
            }
            return
        }
        // 本文と Enter を分離して送る。
        // Claude Code (Ink 製 TUI) は bracketed paste を有効にしており、
        // 本文と \r を一度に送ると \r も paste の一部とみなされ submit されないため、
        // 本文の入力処理が終わる間 (≈0.3s) を挟んでから \r を送って submit させる。
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            terminal.send(txt: prompt)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.3) {
            terminal.send(txt: "\r")
        }
        // Enter 送信後 0.7s で ready とみなし、待機中の sendMessage を flush する。
        // 0.7s は従来 dispatchHandoff / sendRecommendedPrompt が使っていた固定遅延 6.0s と
        // 等価 (5.3 + 0.7 = 6.0) で、過去実績値を温存しつつ仕組みを「状態遷移ベース」に置き換える。
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            self?.markReady()
        }
    }

    /// isReady を true にし、保留中のメッセージを順次 sendMessage で flush する。
    private func markReady() {
        isReady = true
        let messages = pendingMessages
        pendingMessages.removeAll()
        for message in messages {
            sendMessage(message)
        }
    }
}
