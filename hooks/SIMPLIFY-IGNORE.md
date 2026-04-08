# simplify-ignore フック

`/code-simplify` に対するブロックレベルの保護。決して簡略化されてはいけないコードをマークします — モデルはそのコードを見ません。

## セットアップ

1. 保護したいブロックに注釈を付けます:

```js
/* simplify-ignore-start: perf-critical */
// 手動でアンロールした XOR — ループより 3 倍速い
result[0] = buf[0] ^ key[0];
result[1] = buf[1] ^ key[1];
result[2] = buf[2] ^ key[2];
result[3] = buf[3] ^ key[3];
/* simplify-ignore-end */
```

2. `.claude/settings.json` にフックを追加します:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PROJECT_DIR}/hooks/simplify-ignore.sh" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PROJECT_DIR}/hooks/simplify-ignore.sh" }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PROJECT_DIR}/hooks/simplify-ignore.sh" }]
      }
    ]
  }
}
```

3. `/code-simplify` を実行します — 保護されたブロックは `/* BLOCK_de115a1d: perf-critical */` のようなプレースホルダに置き換わります。モデルは保護された実装を見ずに、周囲のコードについて推論します。

> **Note:** フックは一時バックアップを `.claude/.simplify-ignore-cache/` に保存します。このパスを `.gitignore` に追加することを忘れないでください。

## しくみ

1 つのスクリプトが 3 つのフックイベントに対応します:

| イベント | アクション |
|---|---|
| `PreToolUse Read` | ファイルをバックアップし、ブロックを `BLOCK_<hash>` プレースホルダにその場で置き換える |
| `PostToolUse Edit\|Write` | プレースホルダを実コードに展開し、モデルの変更を保存し、再フィルタする |
| `Stop` | セッション終了時にすべてのファイルをバックアップから復元する |

各ブロックはコンテンツハッシュされ（`shasum`/`sha1sum` による 8 桁の 16 進数）、モデルがプレースホルダを複製したり並べ替えたりしてもラウンドトリップは曖昧になりません。キャッシュはプロジェクトスコープで、セッション間の干渉を防ぎます。

## 注釈構文

```js
/* simplify-ignore-start */           // 基本 — ブロックを隠す
/* simplify-ignore-start: reason */   // 理由付き — プレースホルダに表示される
/* simplify-ignore-end */
```

任意のコメントスタイル（`//`、`/*`、`#`、`<!--`）が動作します。1 ファイル内の複数ブロックや単一行ブロックをサポートします。プレースホルダは元のコメント構文を維持します（例: Python なら `# BLOCK_xxx`、HTML なら `<!-- BLOCK_xxx -->`）。

## クラッシュリカバリ

Claude Code が Stop フックを発火せずにクラッシュした場合、ディスク上のファイルには `BLOCK_<hash>` プレースホルダが残っているかもしれません。手動で復元するには:

```bash
echo '{}' | bash hooks/simplify-ignore.sh
```

バックアップはプロジェクトディレクトリ内の `.claude/.simplify-ignore-cache/` に保存されます。

## 既知の制限

- **単一行ブロックは行全体を隠す。** `simplify-ignore-start` と `simplify-ignore-end` が他のコードと同じ行にある場合、注釈部分だけでなく行全体がモデルから隠されます。注釈は専用の行に書きましょう。
- **コメント接尾辞の検出は `*/` と `-->` のみ。** 非標準のコメント終了記号を持つテンプレートエンジン（ERB の `%>`、Blade の `--}}`）では不整合なプレースホルダが生成されることがあります。代わりに `#` や `//` スタイルのコメントを使いましょう。
- **フォールバック展開は段階的で厳密ではない。** モデルがプレースホルダのフォーマットを変更した場合（例: reason テキストの変更）、フックは段階的に緩い一致を試みます: 完全プレースホルダ → prefix+hash+suffix → hash のみ。hash のみのフォールバックでは装飾的な残骸（例: 余分な `:` や reason テキスト）が残る可能性があります。その場合は stderr に警告が出力されます。
- **ファイルのリネームはプレースホルダを残す。** モデルがシェルコマンドでファイルをリネームまたは移動した場合、新しいファイルに `BLOCK_<hash>` プレースホルダが残ります。セッション停止時に元のコードは `<old-filename>.recovered` として保存されます。新しいファイルには手動で復元する必要があります。

## 必要要件

- `jq`、`shasum` または `sha1sum`（自動検出）、Bash 3.2+
