#!/usr/bin/env bash
# Aidea の品質ゲートを順に実行し、最後に PR / 完了報告に貼る「検証」欄を生成する。
#
# 目的は 2 つ:
#   1. 機械で守れるものを機械で守る (ビルド / テスト / docs 整合)
#   2. **検証欄を人手で書かせない** — 実機確認は誰も自動化できないため、
#      このスクリプトは常に「未実施 (人間の確認待ち)」と出力する。
#      実際に触って確認した人だけが、その行を手で書き換える。
#
# 使い方:
#   scripts/gate.sh              # 全ゲート実行 + 検証欄を出力
#   scripts/gate.sh --fast       # ビルド / テストを飛ばし docs 検査のみ (docs 変更時)
#
# 終了コード: 0 = 全ゲート通過 / 1 = いずれか失敗

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FAST=0
[ "${1:-}" = "--fast" ] && FAST=1

build_result="スキップ (--fast)"
test_result="スキップ (--fast)"
links_result=""
specs_result=""
failed=0

run_gate() {
  local name="$1"; shift
  echo "── ${name} ────────────────────────────────"
  if "$@"; then
    echo "✅ ${name}"
    return 0
  else
    echo "❌ ${name}"
    failed=1
    return 1
  fi
}

if [ "$FAST" -eq 0 ]; then
  if run_gate "ビルド" env -C "$REPO_ROOT/Aidea" xcodebuild \
      -project Aidea.xcodeproj -scheme Aidea -configuration Debug \
      build CODE_SIGNING_ALLOWED=NO -quiet; then
    build_result="成功"
  else
    build_result="**失敗**"
  fi

  if run_gate "ユニットテスト" "$REPO_ROOT/scripts/run-tests.sh"; then
    test_result=$(cat /tmp/aidea-test-summary.txt 2>/dev/null || echo "成功")
  else
    test_result="**失敗**"
  fi
fi

if run_gate "docs リンク検査" python3 scripts/check-docs-links.py; then
  links_result="OK"
else
  links_result="**違反あり**"
fi

if run_gate "specs 実装詳細検査" python3 scripts/check-spec-impl-details.py; then
  specs_result="OK"
else
  specs_result="**違反あり**"
fi

cat <<REPORT

════════════════════════════════════════════
PR / 完了報告に貼る「検証」欄 (このまま貼る):
════════════════════════════════════════════

## 検証

- ビルド: ${build_result}
- ユニットテスト: ${test_result}
- docs リンク検査: ${links_result}
- specs 実装詳細検査: ${specs_result}
- **実機確認: 未実施 (確認できるのは人間だけ)**

════════════════════════════════════════════
REPORT

if [ "$failed" -ne 0 ]; then
  echo "ゲート失敗。修正してから再実行してください。"
  exit 1
fi
echo "全ゲート通過。"
