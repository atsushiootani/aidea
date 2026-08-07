#!/usr/bin/env python3
"""docs/specs/ の実装詳細ルール (docs/LAYOUT.md) を機械検査する。

LAYOUT.md「実装詳細ルール (specs は実装知識ゼロで読めること)」の
「避ける」パターンのうち、機械的に判定できるものを検出する。
「残してよい」具体値 (タイミング / 送出キー / tmux 名 / ファイルパス / JSON) は検出しない。

- ERROR: 誤検知しないパターン。ゲートを落とす
    - Swift コードブロック (```swift)
    - プロパティラッパ (@Observable / @Published / @State / @FocusState / ObservationIgnored 等)
    - Swift のラベル付きメソッドシグネチャ (`loadCommand(for:)` — Swift 特有の記法)
- WARN: 誤検知しうるパターン。報告のみでゲートは落とさない
    - .swift ファイル名 (git の出力例・パス検出 regex の例示・hook の対象条件など
      「実装への参照ではない例示」と機械的に区別できないため)
    - 引数なしのメソッド呼び出し風 (`reload()` — 他言語やシェルにも現れる)

例外ファイル (LAYOUT.md で明示): architecture.md / aspects/view-hierarchy.md
終了コード 0 = OK (WARN があっても 0) / 1 = ERROR あり。
"""

import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
SPECS = REPO_ROOT / "docs" / "specs"

# LAYOUT.md「例外」: 構造の地図が目的のためクラス名・ファイルパスの列挙を許可
EXEMPT = {
    SPECS / "architecture.md",
    SPECS / "aspects" / "view-hierarchy.md",
}

PROPERTY_WRAPPERS = re.compile(
    r"@(Observable|Published|State|StateObject|ObservedObject|EnvironmentObject|FocusState|AppStorage|Binding)\b"
    r"|\bObservationIgnored\b"
)
SWIFT_CODE_FENCE = re.compile(r"^\s*```swift\b", re.MULTILINE)
SWIFT_SOURCE_PATH = re.compile(r"[A-Za-z0-9_/]+\.swift\b")
# Swift のラベル付き引数 `foo(bar:)` `foo(_:)` `foo(a:b:)` — バッククォート内のみ対象
LABELED_SIGNATURE = re.compile(r"`[a-z][A-Za-z0-9]*\((?:[A-Za-z0-9_]*:)+\)`")
# 引数なし呼び出し `reload()` — 誤検知しうるので WARN
BARE_CALL = re.compile(r"`[a-z][A-Za-z0-9]*\(\)`")

CHECKS_ERROR = [
    ("Swift コードブロック", SWIFT_CODE_FENCE),
    ("プロパティラッパ", PROPERTY_WRAPPERS),
    ("メソッドシグネチャ", LABELED_SIGNATURE),
]

CHECKS_WARN = [
    (".swift ファイル名", SWIFT_SOURCE_PATH),
    ("メソッド呼び出し風", BARE_CALL),
]


def main() -> int:
    files = [p for p in sorted(SPECS.rglob("*.md")) if p.resolve() not in EXEMPT]
    if not files:
        print("docs/specs/ に Markdown が見つかりません", file=sys.stderr)
        return 1

    errors: list[str] = []
    warnings: list[str] = []

    for path in files:
        rel = path.relative_to(REPO_ROOT)
        lines = path.read_text(encoding="utf-8").splitlines()
        for lineno, line in enumerate(lines, start=1):
            for label, pattern in CHECKS_ERROR:
                for m in pattern.finditer(line):
                    errors.append(f"{rel}:{lineno}: {label}: {m.group(0)}")
            for label, pattern in CHECKS_WARN:
                for m in pattern.finditer(line):
                    warnings.append(f"{rel}:{lineno}: {label}: {m.group(0)}")

    for item in warnings:
        print(f"WARN  {item}")
    for item in errors:
        print(f"ERROR {item}")

    print(
        f"\n検査した specs: {len(files)} ファイル "
        f"(例外 {len(EXEMPT)} 件を除く) / ERROR {len(errors)} / WARN {len(warnings)}"
    )
    if errors:
        print("実装詳細ルール違反があります: docs/LAYOUT.md#実装詳細ルール-specs-は実装知識ゼロで読めること")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
