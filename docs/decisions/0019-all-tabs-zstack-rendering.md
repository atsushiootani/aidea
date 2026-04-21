---
title: "0019: 全 Tab の SessionView を ZStack で常駐レンダリングする"
description: SwiftTerm の detach 時クリア挙動を回避するため、Pane 内の全 Tab を ZStack で常時レンダリングする暫定対処。Tool 別分岐への進化余地あり
status: 暫定
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-21
---

# 0019: 全 Tab の SessionView を ZStack で常駐レンダリングする

**日付**: 2026-04-21

## 背景

Aidea の Pane は複数の Tab を持ち、ユーザーがタブを切り替えながら作業する。素朴な実装としては「アクティブな Tab の SessionView だけ描画、非アクティブな Tab は描画しない」が自然だが、これを採用すると Terminal セッションで重大な問題が起きた。

### SwiftTerm の detach 時挙動

`SwiftTerm.TerminalView` (本プロジェクトでは `PersistentTerminalView` としてラップ) は、自身が superview から外れる (`removeFromSuperview` 等) ときに **内部リフローが走り、可視行 (visible rows) がクリアされる** という挙動を持つ。

SwiftUI の `NSViewRepresentable` は View 階層から外れると `dismantleNSView` が走り、内包する NSView は superview から detach される。結果として:

```
Tab A (Terminal) アクティブ
    ↓ ユーザーが Tab B に切替
Terminal の View が hierarchy から外れる
    ↓ NSView が superview から detach
SwiftTerm が internal reflow を走らせ visible rows がクリア
    ↓ 再び Tab A に戻る
Terminal のバッファが消えた状態で表示される
```

### 影響範囲

`SwiftTerm.TerminalView` を使う Tool に限定される。具体的には:

| Tool | 影響あり？ | 理由 |
|---|---|---|
| **Terminal** | ✅ あり | SwiftTerm 直接使用 |
| **Claude** | ✅ あり | SwiftTerm を共用 (`PersistentTerminalView`) |
| **Web (WKWebView)** | ⚠️ 要検証 | ページ状態は WKWebView 内部で保持されるはずだが、動画再生・フォーム入力等の挙動は未確認 |
| **Filer / Preview / Git / GitDiff / Kit** | ❌ なし | 状態は SessionState 側で保持、再生成可能 |

## 判断

**Pane 内の全 Tab の SessionView を ZStack で常時レンダリングし、非アクティブな Tab は `opacity(0)` + `allowsHitTesting(false)` で隠す。**

実装: [PaneView.swift](../../Aidea/Aidea/Views/Layout/PaneView.swift) の `sessionStack`。

```swift
private var sessionStack: some View {
    ZStack {
        ForEach(pane.tabs, id: \.self) { id in
            let isActive = (pane.activeSessionID == id)
            registry.view(for: id)
                .opacity(isActive ? 1 : 0)
                .allowsHitTesting(isActive)
        }
    }
}
```

## 理由

1. **SwiftTerm の detach 時クリアを完全に回避できる** — NSView が一度も superview から外れないため、リフローが発生しない
2. **最小変更で全 Tool に対して安全側に倒せる** — 影響を受けない Tool についても害は副作用 (後述) のみで、機能的な破綻はない
3. **SwiftTerm の内部挙動に依存する fork やフックを避けられる** — 外部依存ライブラリの内部動作に踏み込まない
4. **Tab 切替操作が単純な opacity 切替で完結し、状態復元のコードが不要**

## トレードオフ (副作用)

全 Tab を常駐させる結果、以下の副作用が生じる:

- **メモリ**: 開いている全 Tab の View Tree が同時に hierarchy 内に存在する
- **SwiftUI 更新サイクル**: 非アクティブ Tab の View も `body` 評価対象になる (描画自体は opacity 0 で省略されるが計算は走る)
- **バックグラウンド動作**: Web の JS タイマー、動画/アニメーションが裏で走り続ける可能性
- **Hit-testing 分岐コスト**: `.allowsHitTesting(isActive)` で対処しているが、その分岐自体は走る
- **デバッグ可読性**: 「見えていない View が動いている」状態が直感に反する

これらは現時点で実用上の問題を引き起こしていないため受容するが、Tab 数が増えた場合や複雑な Web コンテンツを扱う場合に顕在化する可能性がある。

## 今後の検討余地

本判断は **暫定対処** であり、将来見直しの余地がある。検討候補:

### 案 A: Tool 別に ZStack / 切替を分岐 (有力)

`SwiftTerm` を使う Tool だけ ZStack 常駐、それ以外は active Tab のみレンダリングする条件分岐を入れる。

```swift
ForEach(pane.tabs, id: \.self) { id in
    if requiresPersistentRendering(id.tool) {
        registry.view(for: id)
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
    } else if isActive {
        registry.view(for: id)
    }
}
```

**長所**: 最小変更で副作用を Terminal / Claude に限定。**短所**: SessionView の create/dismantle が頻発するため、各 SessionState の NSView キャッシュ機構が正しく動作することの保証が必要。

### 案 B: SwiftTerm の detach 問題自体を解決

`PersistentTerminalView` の `viewWillMove(toSuperview:)` をフックしてバッファを scrollback に退避し、再 attach 時に復元する。**長所**: 根本対処。**短所**: SwiftTerm の内部挙動に依存、メンテナンス負担大。

### 案 C: NSView を Pane 切替対象から外し、ContentView 直下に固定配置する

NSView を Pane 階層に置かず、表示位置だけ Pane に追従させる方式。**長所**: SwiftUI の dismantle が一切走らない。**短所**: 大規模リファクタ、レイアウト計算が複雑、通常のタブ概念から外れる。

### 検討トリガー

以下のいずれかが顕在化したタイミングで再検討する:

- メモリ使用量が問題になる規模 (Tab 数が常時 10+ 等)
- Web Tab で意図しないバックグラウンド動作 (動画再生、JS タイマー暴走) が報告される
- SwiftUI 更新サイクル由来のパフォーマンス劣化が観測される

## 関連

- [PaneView.swift](../../Aidea/Aidea/Views/Layout/PaneView.swift) — `sessionStack` の実装
- [PersistentTerminalView.swift](../../Aidea/Aidea/Sessions/Terminal/PersistentTerminalView.swift) — SwiftTerm ラッパ
- [docs/specs/sessions/session.md](../specs/sessions/session.md) — Session / SessionState の役割分担
- 導入コミット: `659db91` (`feat: introduce Tool/Session/Tab concept model with persistent tabs`)
