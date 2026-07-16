---
title: E2E キー入力シミュレーション (実機自動テスト) の知見
description: OS レベルのキー入力シミュレーションによる E2E テストの作業記録と再開手順 (TCC / CGEvent / IME)
derived_from: []
syncs_with: []
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-05
---

# E2E キー入力シミュレーション (実機自動テスト) の知見

issue #125 (Preview 編集モードで日本語入力中に文字が消える) の実機検証のために試した、
**OS レベルのキー入力シミュレーションによる E2E テスト**の作業記録と再開手順。
2026-07-05 時点では **TCC (アクセシビリティ権限) の付与で中断**しており、修正自体は
手元の手動確認 + インプロセス機構検証で担保した。将来、実機 E2E を自動化するときは
ここから再開する。

## ゴール

1. ビルドした Aidea.app をテスト用ワークスペースで起動する
2. キー入力をシミュレートして UI を操作する (Filer → Preview → edit モード → 文字入力)
3. **日本語 IME の変換中状態を実際に作り**、自動保存の再レンダリングを跨がせてから確定する
4. 保存されたファイル内容を読んで、入力が意図通り反映されたことを機械的に検証する

## 到達した構成 (2026-07-05)

### テスト環境

| 要素 | 内容 |
|---|---|
| テストワークスペース | `/tmp/aidea-ime-test/` (`test.md` を配置) |
| テスト対象インスタンス | `open -n -a <DerivedData>/Aidea.app --args --project-root /tmp/aidea-ime-test` で本番とは別プロセス起動 |
| キー入力シミュレータ | `/tmp/aidea-ime-test/AideaKeySim.app` (下記 typer.swift をコンパイルした単機能アプリ) |
| 検証方法 | 500ms 自動保存後の `test.md` の中身を読んで期待文字列と比較 |

### キー入力シミュレータ (typer.swift → AideaKeySim.app)

- CGEvent (`CGEventPost` + `.cghidEventTap`) でキーの down/up を送出する。
  この経路は実キーボードと同じく **IME (Kotoeri) を通る**ため、日本語変換中の状態を本物同様に作れる
- 入力ソース切替は TIS API (`TISSelectInputSource`)。**アクセシビリティ権限不要**
  - 日本語: `com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese`
  - 英語: `com.apple.keylayout.ABC`
- 対象アプリのアクティブ化は `NSRunningApplication(processIdentifier:).activate()`。権限不要
- コマンド列を引数で渡す DSL: `activate:<pid>` / `ime:ja|en` / `type:<romaji>` / `key:return` / `combo:cmd+alt+1` / `sleep:<ms>`
- `open` 経由起動では stdout が拾えないため、全ログを `/tmp/aidea-ime-test/typer-log.txt` に書く

### 想定テストシナリオ (未実施)

```
1. AideaKeySim: activate:<テストインスタンスPID>
2. combo:cmd+alt+1        # Filer にフォーカス
3. key:down key:return    # test.md を選択して Preview で開く
4. type:e                 # edit モードへ
5. ime:en type:abc  sleep:1000            # 英字入力 → 自動保存
6. ime:ja type:nihongo sleep:1000         # 変換中のまま 1 秒待つ (自動保存の再レンダリングを跨ぐ = 回帰トリガー)
7. key:return sleep:1000                  # 確定 → 自動保存
8. ime:en                                 # 入力ソースを戻す
9. test.md を読んで "abcにほんご" が含まれることを検証
```

ステップ 6 が核心。修正前はここで未確定文字列「にほんご」が破棄されていた。

## ブロッカー: TCC (アクセシビリティ権限)

`CGEventPost` によるキー送出には**アクセシビリティ権限**が必要。ここで得た知見:

- **tmux 配下のプロセスは TCC の帰属が tmux になる**。Aidea 内の Claude (Companion) セッションは
  `Aidea → tmux server → zsh → claude` の系譜なので、そこから spawn した CLI の責任プロセスは
  `/opt/homebrew/bin/tmux`
- **責任プロセスがアプリバンドルでない場合、TCC の許可プロンプトが表示されないことがある**。
  `osascript` の System Events 呼び出しは権限エラーではなく **AppleEvent タイムアウト (-1712)** になり、
  `AXIsProcessTrustedWithOptions(prompt: true)` もダイアログが出ないまま false を返し続けた
- 対策として **単機能の .app バンドル (AideaKeySim.app) を作成**した。`open -a ... --args <cmd>` で起動すれば
  責任プロセスがそのアプリ自身になり、プロンプトが正しく表示される
  - ただし**バイナリを直接実行すると責任プロセスは呼び出し元 (tmux) のまま**なので、必ず `open` 経由で使う
- アドホック署名 (`codesign -s -`) で問題ない。同一バイナリのコピーは cdhash が同じため、
  どのコピーに許可しても他のコピーにも効く
- 再開時は「システム設定 → プライバシーとセキュリティ → アクセシビリティ」に **AideaKeySim** を
  追加して ON にする (`probe` モードでプロンプト表示 + 付与待ちができる)

## 代替手段: インプロセス機構検証 (実施済み・PASS)

OS レベルのシミュレーションが権限で止まっている間、**NSTextInputClient API を直接呼ぶ**ことで
IME 変換中の状態を作る機構検証を行った (アクセシビリティ権限不要)。

- 手法: テスト用ウィンドウに編集ビューを表示し、`setMarkedText` で未確定文字列「にほんご」を注入 →
  親 View の状態変更で再レンダリングを起こす → `hasMarkedText()` と storage 内容を検査 →
  `insertText` で確定して binding を検査
- 結果 (2026-07-05): 修正前ロジックは再レンダリングで未確定文字列が破棄され (バグ再現)、
  修正後ロジックは保持・確定とも正常 (issue #125 の修正根拠)
- スクリプト: `/tmp/aidea-ime-test/ime_harness.swift` (修正前/修正後の updateNSView を並置して比較実行)

XCUITest は不採用: macOS の UI テストも結局 Xcode Helper へのアクセシビリティ付与が必要で、
プロジェクトに UI テストターゲットを追加するコストに見合わない。

## 再開手順 (チェックリスト)

1. `/tmp/aidea-ime-test/` が消えていたら本ドキュメントの付録から `typer.swift` を復元し、
   `.app` バンドル化する (付録参照)
2. `open -a AideaKeySim.app --args probe` で権限プロンプトを表示し、アクセシビリティを付与
3. テストインスタンスを起動: `open -n -a <Aidea.app> --args --project-root /tmp/aidea-ime-test`
4. 上記「想定テストシナリオ」を実行し、`test.md` の中身で検証
5. 自動化が安定したら、シナリオを `docs/conventions/testing.md` の手動確認チェックリストの
   該当項目と置き換えることを検討する

## 付録: typer.swift (AideaKeySim)

ビルド方法:

```bash
mkdir -p AideaKeySim.app/Contents/MacOS
# Info.plist: CFBundleExecutable=AideaKeySim / CFBundleIdentifier=com.aidea.keysim / LSUIElement=true
swiftc -O typer.swift -o AideaKeySim.app/Contents/MacOS/AideaKeySim
codesign --force -s - AideaKeySim.app
```

```swift
// CGEvent ベースのキー入力シミュレータ
// 使い方 (必ず open 経由で起動する。直接実行すると TCC の責任プロセスが呼び出し元になる):
//   open -a AideaKeySim.app --args <cmd> [<cmd> ...]
//   check              ... 信頼状態を probe-result.txt に書くだけ
//   probe              ... 権限プロンプトを表示して付与を待つ (最大180秒)
//   activate:<pid>     ... 指定 PID のアプリをアクティブ化
//   ime:ja | ime:en    ... 入力ソースを 日本語(Kotoeri) / ABC に切替
//   type:<text>        ... 1 文字ずつ keydown/up を送出 (US 配列の英数字・記号一部)
//   key:<name>         ... return / esc / down / up / tab / space
//   combo:<mods>+<c>   ... 修飾キー付き (例 combo:cmd+alt+1)
//   sleep:<ms>         ... 待機
import AppKit
import Carbon.HIToolbox

let keymap: [Character: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
    "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
    "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
    " ": 49, ".": 47, ",": 43, "/": 44, ";": 41, "-": 27,
]
let named: [String: CGKeyCode] = [
    "return": 36, "tab": 48, "space": 49, "esc": 53,
    "down": 125, "up": 126, "left": 123, "right": 124,
]

func post(_ code: CGKeyCode, flags: CGEventFlags = [], delayMs: UInt32 = 60) {
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)!
    down.flags = flags
    down.post(tap: .cghidEventTap)
    usleep(20_000)
    let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)!
    up.flags = flags
    up.post(tap: .cghidEventTap)
    usleep(delayMs * 1000)
}

func selectInputSource(id: String) -> Bool {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
          let source = list.first else {
        log("input source not found: \(id)")
        return false
    }
    let status = TISSelectInputSource(source)
    log("selectInputSource \(id): status=\(status)")
    return status == noErr
}

// open 経由の起動では stdout が拾えないため、全出力をログファイルにも書く
let logPath = "/tmp/aidea-ime-test/typer-log.txt"
func log(_ s: String) {
    print(s)
    let line = s + "\n"
    if let handle = FileHandle(forWritingAtPath: logPath) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
    }
}
func report(_ s: String) {
    log(s)
    try? s.write(toFile: "/tmp/aidea-ime-test/probe-result.txt", atomically: true, encoding: .utf8)
}

// check モード: プロンプトを出さず信頼状態だけ書く
if CommandLine.arguments.dropFirst().first == "check" {
    report("trusted: \(AXIsProcessTrusted())")
    exit(AXIsProcessTrusted() ? 0 : 2)
}

// probe モード: 権限プロンプトを表示して付与を待つ (最大 180 秒)
if CommandLine.arguments.dropFirst().first == "probe" {
    if AXIsProcessTrusted() {
        report("trusted: true")
        exit(0)
    }
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(opts)
    for _ in 0..<180 {
        if AXIsProcessTrusted() {
            report("trusted: true")
            exit(0)
        }
        sleep(1)
    }
    report("trusted: false (timeout)")
    exit(2)
}

guard AXIsProcessTrusted() else {
    log("ERROR: accessibility not granted")
    exit(2)
}

for arg in CommandLine.arguments.dropFirst() {
    if arg.hasPrefix("activate:") {
        let pid = pid_t(arg.dropFirst(9))!
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            log("no app with pid \(pid)"); exit(1)
        }
        app.activate()
        usleep(500_000)
        log("activated pid \(pid) (\(app.localizedName ?? "?"))")
    } else if arg == "ime:ja" {
        _ = selectInputSource(id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese")
        usleep(500_000)
    } else if arg == "ime:en" {
        _ = selectInputSource(id: "com.apple.keylayout.ABC")
        usleep(500_000)
    } else if arg.hasPrefix("type:") {
        for ch in arg.dropFirst(5) {
            guard let code = keymap[ch] else { log("unmapped char: \(ch)"); continue }
            post(code, delayMs: 90)
        }
        log("typed: \(arg.dropFirst(5))")
    } else if arg.hasPrefix("key:") {
        let name = String(arg.dropFirst(4))
        guard let code = named[name] else { log("unknown key: \(name)"); exit(1) }
        post(code)
        log("key: \(name)")
    } else if arg.hasPrefix("combo:") {
        let parts = arg.dropFirst(6).split(separator: "+").map(String.init)
        var flags: CGEventFlags = []
        var keyPart: String?
        for p in parts {
            switch p {
            case "cmd": flags.insert(.maskCommand)
            case "alt", "opt": flags.insert(.maskAlternate)
            case "shift": flags.insert(.maskShift)
            case "ctrl": flags.insert(.maskControl)
            default: keyPart = p
            }
        }
        guard let kp = keyPart else { log("combo missing key"); exit(1) }
        let code: CGKeyCode
        if let c = named[kp] { code = c }
        else if kp.count == 1, let c = keymap[Character(kp)] { code = c }
        else { log("combo unknown key: \(kp)"); exit(1) }
        post(code, flags: flags)
        log("combo: \(arg.dropFirst(6))")
    } else if arg.hasPrefix("sleep:") {
        let ms = UInt32(arg.dropFirst(6)) ?? 0
        usleep(ms * 1000)
        log("slept \(ms)ms")
    } else {
        log("unknown cmd: \(arg)"); exit(1)
    }
}
log("done")
```
