# Design Principles (設計原則)

Aidea のコードベース全体で常に意識する設計原則。
個別の判断に迷ったときはここに立ち返る。

[rules.md](./rules.md) の Always / Confirm First / Never は「具体的なルール」、
ここに書かれているのは「ルールの背景にある思想」。

---

## 1. Tell, Don't Ask (聞くな、言え)

> オブジェクトの型や状態を調べて分岐するのではなく、オブジェクトに「やって」と言え。

```swift
// ❌ Ask: 親が子の型を調べて分岐する
switch session.tool {
case .filer:    makeFirstResponder(outlineView)
case .terminal: makeFirstResponder(terminalView)
case .kit:      isFocused = true
...
}

// ✅ Tell: 子に「アクティブになったよ」と伝えるだけ
session.state.didBecomeActive(session: session)
```

**なぜ守るか:**
- 親が子の内部を知る必要がなくなる
- 新しい Session 種別を追加するとき、親のコードを修正しなくてよい
- 「この Session は何をするか」をその Session のコードだけ読めば分かる

**違反のサイン:**
- `switch` や `if` でオブジェクトの型 / enum ケースを調べて処理を分けている
- メソッドの引数に「何をすべきか」のフラグや型情報を渡している

---

## 2. Single Responsibility Principle — SRP (単一責務の原則)

> クラスやモジュールが変更される理由は 1 つだけであるべき。

```swift
// ❌ 1 つのクラスが「データロード」と「UI 表示」と「永続化」を全部やる
class FilerManager {
    func loadFiles() { ... }
    func renderOutlineView() { ... }
    func saveExpandedState() { ... }
}

// ✅ 責務ごとに分離
class FileTreeLoader { func load(...) -> [FileTreeNode] }       // データ取得
class FileTreeViewController { ... }                             // UI 表示
struct FilerSnapshot { ... }                                     // 永続化構造
```

**Aidea での適用:**
- **SessionState** = ツール固有の状態のみ
- **Session** = ライフサイクルとフォーカス管理
- **SessionRegistry** = 全 Session の一覧管理と検索
- **LayoutConfig** = ペイン構成の管理
- **WorkspaceSnapshotManager** = 永続化ロジック

**違反のサイン:**
- 1 つのクラスが 300 行を超えている
- 「○○ も △△ もこのクラスでやっている」と説明してしまう
- 変更理由が 2 つ以上あるクラスがある

---

## 3. Open/Closed Principle — OCP (開放/閉鎖の原則)

> 拡張に対して開いて (Open)、修正に対して閉じよ (Closed)。

```swift
// ❌ 新しい Tool を追加するたびに親の switch を修正する
func createView(for tool: Tool) -> some View {
    switch tool {
    case .filer: FilerView()
    case .kit: KitView()
    case .newTool: NewToolView()  // ← 追加するたび修正
    }
}

// ✅ プロトコルで拡張。新しい Tool は新しい SessionState を実装するだけ
protocol SessionState {
    func didBecomeActive(session: Session)
}
// NewToolSessionState: SessionState を実装するだけ。既存コード修正不要。
```

**注意:** Swift の enum は case を追加すると switch で全箇所修正が必要になる。
これは enum の本質的な制約。Tool enum のように「種類が限定的で安定している」ものは
enum で良いが、**振る舞いの分岐は enum の switch ではなくプロトコルメソッドで解決する**。

**Aidea での適用:**
- `SessionState.didBecomeActive()` — 型ごとの振る舞いを追加コードで実装
- `EmacsNavigation.handle()` — 共通ナビゲーションは 1 箇所、Tool 固有は各 View
- ファイル種別ハンドラ (Preview) — 新しい種別は新しいハンドラを追加するだけ

---

## 4. Polymorphism (多態性)

> 型によって振る舞いが変わるとき、条件分岐 (if/switch) ではなくプロトコル/オーバーライドで解決する。

GRASP パターン (General Responsibility Assignment Software Patterns) の 1 つ。
Tell, Don't Ask と OCP の実装手段。

```swift
// ❌ 条件分岐
if state is FilerSessionState {
    (state as! FilerSessionState).controller.outlineView...
} else if state is KitSessionState {
    ...
}

// ✅ プロトコルメソッド
state.didBecomeActive(session: session)
// 各 SessionState が自分で適切な処理を行う
```

**Aidea での適用:**
- `SessionState` プロトコル — ライフサイクル (`didBecomeActive` / `didResignActive`)。AppKit 系 state は `SessionFocusBridge` を保持してフォーカス契約を履行
- `FileTreeLoader.iconName(for:)` — 拡張子で分岐するのは「データに基づく分岐」なので OK
  (型の分岐とデータの分岐は区別する)

---

## 5. Information Expert (情報エキスパート)

> その責務を果たすのに必要な情報を最も多く持っているクラスに、その責務を割り当てよ。

GRASP パターンの 1 つ。

```
「Filer がアクティブになったら outlineView にフォーカスすべき」
  → この情報を一番知ってるのは FilerSessionState
  → FilerSessionState.didBecomeActive() に書く

「Preview の firstResponder 候補の NSView は表示コンテンツで変わる」
  → 表示コンテンツを知ってるのは子ビュー (NSTextPreview 等)
  → 子ビューが state.focusBridge.setView(_:) で bridge に報告する
```

**違反のサイン:**
- あるクラスが別のクラスの内部プロパティを読んで判断している
- 「この情報ならあっちのクラスの方が詳しいのに、こっちで処理している」と感じる

---

## 6. Composition over Inheritance (継承より合成)

> クラス階層を深くするのではなく、小さなコンポーネントを組み合わせて構築する。

Aidea では class 継承はほぼ使わず、**プロトコル準拠 + 合成** で構造を作る。

```swift
// ❌ 深い継承
class BaseSessionState { ... }
class FilerSessionState: BaseSessionState { ... }
class TerminalSessionState: BaseSessionState { ... }

// ✅ プロトコル + 合成
protocol SessionState: AnyObject { ... }
final class FilerSessionState: SessionState { ... }  // 継承なし、プロトコル準拠のみ
```

**Aidea での適用:**
- `SessionState` はプロトコル (class 継承ではない)
- `Session` は `SessionState` を合成で保持 (`let state: any SessionState`)
- `LayoutNode` は enum で表現 (class 継承ツリーではない)

---

## 7. Separation of Concerns — SoC (関心の分離)

> 異なる関心事を異なるモジュール/レイヤーに分離する。

Aidea のレイヤー構造:

```
Views/        → UI の表示ロジック (SwiftUI / AppKit ラッパ)
Sessions/     → Session のライフサイクルと状態
Services/     → 副作用 (ファイル I/O, ネットワーク, プロセス起動)
Models/       → 純粋なデータ構造
Tools/        → Tool / Session / LayoutNode の型定義
Utilities/    → 純粋関数ヘルパー
```

**ルール:**
- View は Service を直接呼ばない (SessionState 経由)
- Model は副作用を持たない
- Service は View を知らない

---

## 8. Consistency with Existing Features (既存機能との一貫性)

> 似た役割の機能を追加・拡張するときは、既存の類似機能と UI・挙動・表記・データ表現を揃える。

scheduler と snippet のように「送信先を選ぶ」「ターミナルへ送る」など役割が重なる機能どうしは、
ユーザーの認知モデルを揃えるため、選択肢の並び・ラベル・行の表示形式・解決ロジックを統一する。

例:
- ターミナル送信先は両方とも「タブ名」で指定し、解決は共通の
  `SessionRegistry.tabTitle(for:)` + `sendToTerminal` を使う
- 行の表示は scheduler / snippet とも `→ 送信先 / コマンド` 形式に揃える

**なぜ守るか:**
- ユーザーが片方で覚えた操作をもう片方でもそのまま使える
- 表記・挙動のズレによる小さな摩擦を無くす
- 解決ロジックを共通化でき、実装の二重化も防げる

**違反のサイン:**
- 似た機能なのに、片方は内部 ID・片方は名前で指定するなど表現がバラバラ
- 同じ概念を指すラベル / 行フォーマットが画面ごとに違う
- 一方だけに後付けした挙動が、もう一方に反映されていない

**注意:** [ADR 0033](../decisions/0033-snippet-scheduler-separation.md) のように「認知モデル上はあえて
別物として扱う」分離もある。一貫性は "見た目・操作の揃え" であって、無理に 1 つのモデルへ統合する
ことではない。

---

## まとめ: 判断に迷ったときのチェックリスト

新しい機能を設計するとき、以下を自問する:

1. **この処理は誰が一番詳しい？** → そのクラスに書く (Information Expert)
2. **型で分岐してる？** → プロトコルメソッドにできないか (Polymorphism / Tell, Don't Ask)
3. **既存コードを修正してる？** → 新しいコードの追加だけで済まないか (OCP)
4. **このクラスの変更理由は 1 つか？** → 複数あるなら分割 (SRP)
5. **class 継承を使おうとしてる？** → protocol + 合成の方が良くないか (Composition over Inheritance)
6. **View にビジネスロジックが入ってる？** → Service や SessionState に移す (SoC)
7. **似た機能が既にある？** → UI・挙動・表記を既存と揃える (Consistency with Existing Features)

---

## 参考文献

- **SOLID 原則**: Robert C. Martin (Uncle Bob) — SRP, OCP, LSP, ISP, DIP
- **GRASP パターン**: Craig Larman — Information Expert, Polymorphism, etc.
- **Tell, Don't Ask**: Martin Fowler — https://martinfowler.com/bliki/TellDontAsk.html
- **Composition over Inheritance**: GoF Design Patterns (1994)
