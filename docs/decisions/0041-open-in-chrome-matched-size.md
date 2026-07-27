---
title: "0041: Web タブの表示領域と同じ位置・サイズで Chrome を開く"
description: Web タブの地球アイコンを ⌘クリックすると、subprocess 起動の Chrome CLI 引数でタブと同じ位置・サイズの新規ウィンドウを開く決定
status: 採用
derived_from:
  - docs/decisions/0015-wkwebview-scope-and-chrome-coexistence.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-27
---

# 0041: Web タブの表示領域と同じ位置・サイズで Chrome を開く

**日付**: 2026-07-27

## 背景

[ADR 0015](./0015-wkwebview-scope-and-chrome-coexistence.md) は Aidea 内蔵ブラウザを WKWebView (Safari 相当)
に限定し、Chrome 固有機能が要る場面は外部 Chrome の併用を前提とした。しかし実際には、
Safari 非対応を理由に「このブラウザには対応していません」と表示するだけのサイトに
頻繁に遭遇し、その都度 Chrome を手動で開き直す体験が「Aidea の中でブラウジングしている」
感覚を損なっていた ([issue #272](https://github.com/atsushiootani/aidea/issues/272))。

単に OS デフォルトブラウザ (または Chrome) を開くだけでは、既定の位置・サイズで新規ウィンドウが
出るため、Web タブを閉じて別ウィンドウに切り替わったように感じてしまう。

## 判断

Web タブのツールバー地球アイコンを **⌘クリック**すると、現在の Web タブの表示領域
(WKWebView の画面上の frame) と**同じ位置・サイズ**の新規 Chrome ウィンドウで同じ URL を開く。

- 起動は `WorkspaceLauncher` ([ADR 0030](./0030-multiprocess-one-repo-per-process.md) で確立済みの
  `open -n -a <bundle> --args ...` という `Process` 経由の subprocess 起動パターン)を踏襲し、
  `open -na "Google Chrome" --args --new-window --window-position=X,Y --window-size=W,H <url>` を実行する
- 位置・サイズは Web タブの `WKWebView` を `convert(_:to:)` → `NSWindow.convertToScreen(_:)` で
  screen 座標に変換して求める (`TabPickerAnchor` / `FilerSessionView` の座標変換と同じ手法)
- Chrome の `--window-position` は主画面**左上原点・Y 下向き**を期待するため、AppKit の
  左下原点・Y 上向き座標から変換する
- **Cmd を押さない単純クリックは従来通り** OS デフォルトブラウザで開く (ADR 0015 のまま維持)
- Chrome 未インストール、または Web タブがまだ画面に描画されておらず frame が取得できない場合は
  ⌘クリックでも**単純クリックと同じ OS デフォルトブラウザへフォールバック**する

## 理由

1. **既存パターンの再利用**: subprocess 起動は `WorkspaceLauncher.spawn` と同じ `Process` +
   `/usr/bin/open --args` 経路。`NSWorkspace.OpenConfiguration.arguments` の引数消失バグ
   ([`WorkspaceLauncher.swift`](../../Aidea/Aidea/Services/Workspace/WorkspaceLauncher.swift) のコメント参照)
   を踏まえ、確実に引数が渡る経路を踏襲する
2. **Automation 権限が不要**: AppleScript (`tell application "Google Chrome"`) や Accessibility API
   (`AXUIElement`) で既存 Chrome ウィンドウを操作する案も検討したが、いずれも初回に
   System Settings の Automation 許可ダイアログが出る。新規ウィンドウを起動時引数で
   狙った位置・サイズに出す方式なら、この追加の権限リクエストが一切不要になる
3. **既存ボタンの拡張が最小の学習コスト**: [design-principles.md](../conventions/design-principles.md) の
   「類似機能とのUI一貫性」に従い、新しいボタン/メニューを増やさず既存の地球アイコンに
   ⌘クリックの分岐を足すだけにする。単純クリックの挙動 (ADR 0015 の OS デフォルトブラウザ) は変えない
4. **座標変換は既存資産の再利用**: `TabPickerAnchor.bottomRightScreenPoint` /
   `FilerSessionView` のポップアップ位置計算と同じ「SwiftUI/AppKit 座標 → screen 座標」変換パターンを
   再利用でき、新しい計算方式を持ち込まない

## やらないこと (スコープ外)

- 既存 Chrome ウィンドウの再利用・リサイズはしない (常に新規ウィンドウを起動する)。
  Chrome CLI の `--window-position` / `--window-size` は新規ウィンドウ生成時のみ有効なため、
  「サイズを合わせた新しい窓を開く」ことが本 ADR のスコープ
- Chrome 以外のブラウザ (Firefox 等) への同種の導線は作らない。issue の要望・ADR 0015 の
  Chrome 併用方針に合わせ Chrome 固定とする
- 永続的な設定・トグルは持たない。⌘クリックという都度の操作のみで完結させ、
  新しい Settings 画面や UserDefaults キーを増やさない (このアプリには現状 Settings 画面が無い)

## トレードオフ

- ⌘クリックという新しい「修飾クリック」の意味付けを Web ツールに限定して導入する。
  [keybindings.md](../specs/aspects/keybindings.md) の Terminal 節にある
  「単純クリック = Cmd 修飾の有無は問わない」という既存ルールとは別の挙動になるため、
  Web ツール固有の例外として明記する必要がある
- マルチモニタ環境で Web タブがメインでない画面にある場合、`--window-position` の座標系は
  主画面基準のため、想定とズレる可能性がある (許容する: 単一モニタでの利用が主眼)
