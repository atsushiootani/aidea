---
title: "0035: Web の window.open / target=_blank を新規タブとポップアップ窓に振り分ける"
description: WKUIDelegate を実装し、サイズ指定ありの window.open はフローティング窓、それ以外は新規 Web タブとして開く
status: 提案
derived_from:
  - docs/decisions/0015-wkwebview-scope-and-chrome-coexistence.md
syncs_with:
  - docs/specs/tools/web.md
  - docs/specs/sessions/web.md
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-20
---

# 0035: Web の window.open / target=_blank を新規タブとポップアップ窓に振り分ける

**日付**: 2026-06-20

## 背景

Aidea 内蔵ブラウザ (WKWebView) は `WKUIDelegate` を実装していないため、
ページ内の `window.open()` や `target="_blank"` のリンクが**すべて無視される**。
[ADR 0015](./0015-wkwebview-scope-and-chrome-coexistence.md) の対応表でも
「OAuth popup は `WKUIDelegate` で handle すれば完璧」と記載しながら未実装だった。

このため次のような一般的な Web 操作ができない:

- OAuth ログイン (Google / GitHub 等) の認証ポップアップ
- `target="_blank"` の外部リンク (ドキュメント中の「別タブで開く」)
- `window.open(url)` による新規ウィンドウ表示

## 判断

`WKUIDelegate.webView(_:createWebViewWith:for:windowFeatures:)` を実装し、
**`windowFeatures` のサイズ指定有無で出し先を振り分ける**。

| 起点 | 条件 | 出し先 |
|---|---|---|
| `window.open(url, name, "width=..,height=..")` | windowFeatures に width か height がある | **フローティングポップアップ窓** (独立 NSWindow) |
| `target="_blank"` リンク / `window.open(url)` (サイズ指定なし) | windowFeatures にサイズ指定がない | **新規 Web タブ** (呼び出し元と同じペインの右隣) |

- 生成する子 WKWebView は**必ず WebKit から渡された `configuration` を使う**。
  これにより opener との関係 (`window.opener` / `postMessage` / `window.close()`) が成立し、
  OAuth のコールバックや小窓 UI が正しく動く。
- 子 WKWebView をどちらの経路でも**自前で `load` しない**。WebKit が
  `navigationAction` のリクエストを返した WKWebView に対して自動でロードする。
- ポップアップ窓は `webViewDidClose` で閉じる (`window.close()` に追従)。
- ポップアップ窓 / 子タブの WKWebView にも `uiDelegate` を設定し、入れ子の
  `window.open` も再帰的に扱えるようにする。

## 理由

1. **ブラウザの一般的な挙動に揃える**: `window.open(...,features)` を小窓、
   `target="_blank"` をタブとして扱うのは主要ブラウザの慣習に近く、ユーザの認知モデルに合う。
2. **OAuth を内蔵ブラウザで完結できる**: サイズ指定付きポップアップを独立窓にし、
   `window.close()` / `postMessage` を成立させることで、Google/GitHub ログインが
   外部 Chrome に逃がさず Aidea 内で完結する (ADR 0015 の「Chrome 併用」の対象を狭める)。
3. **既存の Web タブ資産を再利用**: サイズ指定なしは新規 Web タブとして開くことで、
   ナビゲーションツールバー・ページ内検索・永続化など既存機能をそのまま使える。
4. **新規タブの配置は呼び出し元の隣**: リンク元ページのすぐ近くに出すことで文脈を保つ
   (URL クリック routing の `openWeb` が「別ペイン」へ出すのとは別ポリシー。
   `window.open` は "今見ているページから派生した子" なので隣が自然)。

## 配置ポリシーの使い分け

| エントリ | 起点 | 配置 |
|---|---|---|
| `openWeb(for:)` | Terminal/Claude 出力中の URL クリック | 呼び出し元**以外**の最新ペイン |
| 本 ADR (新規タブ) | Web ページ内の `target="_blank"` / `window.open` | 呼び出し元と**同じ**ペインの右隣 |

URL クリックは「ターミナルから Web へ視線を移す」操作なので別ペイン、
ページ内リンクは「同じブラウジング文脈の続き」なので隣、という非対称を意図的に採る。

## やらないこと (スコープ外)

- `windowFeatures` の位置・サイズの厳密な再現はしない (フローティング窓は妥当な既定サイズで出す)。
  width/height は「ポップアップとして扱うか」の判定にのみ使う。
- `WKNavigationDelegate` の新規実装はしない (本 ADR は UI デリゲートのみ)。
- ポップアップブロッカー的な抑制はしない (ユーザ操作起点の `window.open` のみ WebKit が通すため)。
- Chrome 固有 API ([ADR 0015](./0015-wkwebview-scope-and-chrome-coexistence.md) の表) は引き続き対象外。

## トレードオフ

- ポップアップ窓は独立 NSWindow になるため、ペイン内タブとはライフサイクル管理が別系統になる
  (registry が生存参照を保持し、`webViewDidClose` で解放)。
- サイズ指定の有無という単純な判定のため、「サイズ付きだが実体はタブで見たい」ケースは
  ユーザが窓のリンクを Web タブで開き直す必要がある (地球アイコン / 手動操作で吸収)。
