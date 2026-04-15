# Coding Style

Aidea のコーディング規約。静的なルールのみを集約。アーキテクチャは
[../specs/architecture.md](../specs/architecture.md) を参照。

## Swift 規約

- Apple の [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) に従う
- インデントは 4 スペース
- 1 行は 120 文字以内を目安
- 型名は `UpperCamelCase`、変数/関数は `lowerCamelCase`
- 1 ファイル = 1 型 (`struct` / `class` / `enum`) を原則とする

## View 内の変数並び順 (固定)

SwiftUI View のプロパティラッパは以下の順に並べる:

1. `@Binding`
2. `let`
3. `@State`
4. `@StateObject`
5. `@Bindable`
6. `@Query`
7. `@Environment`
8. `@EnvironmentObject`
9. `@FocusState`
10. `var`

## コメント

- すべての `class` / `struct` / `enum` / `func` に**責務を一行で示す**コメントを付ける
- ロジックの「なぜ」を説明するコメントを優先 (「何を」はコードで示す)
- 絵文字はコード・コメントには使わない (ユーザーが明示的に要求した場合のみ)

## 並行性

- I/O は原則 `async/await`
- メインスレッド更新は `@MainActor`
- `Process` 実行・ファイル走査は別 actor / `Task.detached` で行う
- `@Observable` クラスは SwiftUI 側で自動追跡される

## 命名

- **Session** 系クラス: `<Tool>SessionState` `<Tool>SessionView`
- **Loader** 系: `<Tool>Loader` (副作用を持つ Service として扱う)
- ファイル名は型名と一致させる

## import 順

1. `Foundation`
2. 他の Apple framework (`SwiftUI`, `AppKit`, `WebKit`, `CoreServices` 等)
3. `Observation`
4. サードパーティ (`SwiftTerm`)

## エラー処理

- 個人用アプリのため、致命的でない I/O エラーは `try?` で握りつぶすことを許容
- 握りつぶす場合は必ずコメントで理由を書く
- 回復不能なエラーは `fatalError` でなく空状態 (`[]` / `nil`) で代替
