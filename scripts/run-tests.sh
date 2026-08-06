#!/usr/bin/env bash
# Aidea のユニットテスト (AideaTests) を実行する。
#
# UI テストターゲット (AideaUITests) は runner がハングして
# "The test runner hung before establishing connection" で必ず失敗するため、
# -only-testing でユニットテストのみに絞る。素の `xcodebuild test` は使わない。
# 署名証明書に依存しないよう CODE_SIGNING_ALLOWED=NO で走らせる。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT/Aidea"

xcodebuild test \
  -project Aidea.xcodeproj \
  -scheme Aidea \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AideaTests \
  CODE_SIGNING_ALLOWED=NO \
  "$@" 2>&1 | tee /tmp/aidea-test.log | grep -E "Test case .* (passed|failed)|error:" || true

# grep -c は 0 件のとき exit 1 を返すので `|| true` で握り、値だけを取る
passed=$(grep -c "Test case .* passed" /tmp/aidea-test.log || true)
failed=$(grep -c "Test case .* failed" /tmp/aidea-test.log || true)
echo "${passed} passed / ${failed} failed" > /tmp/aidea-test-summary.txt
echo ""
echo "ユニットテスト: $(cat /tmp/aidea-test-summary.txt)"

if [ "${failed}" -gt 0 ] || [ "${passed}" -eq 0 ]; then
  exit 1
fi
