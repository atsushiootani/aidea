#!/usr/bin/env python3
"""docs/ 配下の Markdown リンクとアンカーの整合を検査する。

- ファイルリンク: `](path.md)` の参照先が実在するか
- アンカーリンク: `](path.md#anchor)` の見出しが参照先に実在するか

docs/LAYOUT.md の「インデックス更新の義務」「リンク切れは healthcheck で別途チェックする」
を機械検査に落としたもの。終了コード 0 = OK / 1 = 違反あり。
"""

import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = REPO_ROOT / "docs"

# GitHub のアンカー生成規則の近似:
# インラインリンクをテキストへ解決 → バッククォート除去 → 小文字化 → 空白をハイフン
# → 英数字・ハイフン・アンダースコア以外を除去
_BACKTICK = re.compile(r"`")
_INLINE_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")


def slugify(heading: str) -> str:
    text = _INLINE_LINK.sub(r"\1", heading)
    text = _BACKTICK.sub("", text).strip().lower()
    out = []
    for ch in text:
        if ch.isspace():
            out.append("-")
        elif ch.isalnum() or ch in "-_":
            out.append(ch)
    return "".join(out)


def collect_headings(path: pathlib.Path) -> set[str]:
    headings = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"#{1,6}\s+(.*)", line)
        if m:
            headings.add(slugify(m.group(1)))
    return headings


def main() -> int:
    md_files = sorted(DOCS.rglob("*.md"))
    if not md_files:
        print("docs/ に Markdown が見つかりません", file=sys.stderr)
        return 1

    headings = {p.resolve(): collect_headings(p) for p in md_files}
    link_re = re.compile(r"\]\(([^)#\s]+\.md)(#[^)\s]+)?\)")

    broken_files: list[str] = []
    broken_anchors: list[str] = []

    for path in md_files:
        rel = path.relative_to(REPO_ROOT)
        for m in link_re.finditer(path.read_text(encoding="utf-8")):
            target = (path.parent / m.group(1)).resolve()
            if not target.exists():
                broken_files.append(f"{rel} -> {m.group(1)}")
                continue
            if m.group(2):
                anchor = m.group(2)[1:]
                if anchor not in headings.get(target, set()):
                    broken_anchors.append(f"{rel} -> {m.group(1)}#{anchor}")

    for item in broken_files:
        print(f"リンク切れ: {item}")
    for item in broken_anchors:
        print(f"アンカー切れ: {item}")

    total = len(broken_files) + len(broken_anchors)
    if total:
        print(f"\n検査した Markdown: {len(md_files)} 件 / 違反: {total} 件")
        return 1

    print(f"docs リンク検査 OK ({len(md_files)} ファイル)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
