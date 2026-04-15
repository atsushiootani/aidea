# Vision

Aidea を作る動機と、開発中つねに立ち返るべき **原則** だけを置く。
具体的な仕様 (MVP / 非要件 / 成功基準) は [../specs/SPEC.md](../specs/SPEC.md) を参照。

---

## 作る理由

### 試した道: Vibeyard

Electron 製の AI コーディング IDE (Vibeyard) を試したが、以下の問題が判明:

- `<webview>` タグの制約で **位置情報 (Geolocation) が取れない**
- `<webview>` の popup ハンドリング欠如で **OAuth ログインが壊れる**
- `permission request handler` が未設定で多くの Web API が拒否される
- User-Agent が Electron 由来でサイトによっては bot 扱い
- Chrome プロファイル (Cookie、拡張機能) が使えない

Vibeyard の Inspect / Flow Recording 機能自体は面白いが、
**IDE 固有のバグと永続的に付き合うデメリットが、統合 UX のメリットを上回る** と判断。

### 判断

- Vibeyard は使わない
- 当面の実用環境は **Chrome + Playwright MCP + Claude Code** の組み合わせで済ませる
- **「作る楽しみ」と「長期的な自分仕様」の両立** のため、週末プロジェクトとして自作 IDE を育てる

---

## 原則

> **本来のブラウザの挙動と差異なく開発できることが最優先**
>
> 統合された UX は便利だが、それは手段。本物のブラウザで動くものが動かなかったり、
> 挙動が違ったりすることに耐えてまで統合は求めない。

この原則が技術選定 ([ADR 0001](../decisions/0001-swift-swiftui.md)) と
スコープ判断 ([ADR 0015](../decisions/0015-wkwebview-scope-and-chrome-coexistence.md)) の根拠。
