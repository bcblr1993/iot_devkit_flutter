#!/usr/bin/env bash
# scripts/ui_check.sh
#
# UI 一致性治理一键检查（CI 与本地通用）：
#   1) flutter pub get      —— 同步依赖
#   2) flutter analyze      —— 静态分析（含 custom_lint，待 commit 3 接入后生效）
#   3) flutter test test/widgets/  —— widget smoke
#   4) flutter test test/golden/   —— L2 视觉回归
#
# 失败时：test/golden/failures/*.png 即为 diff 截图（等价 BackstopJS report），
# CI 会把这个目录作为 artifact 上传。
#
# 若需要刷新基线，请改用 scripts/ui_golden_update.sh，并人工 review 截图。

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> [1/4] flutter pub get"
flutter pub get

echo "==> [2/4] flutter analyze --no-pub"
flutter analyze --no-pub

echo "==> [3/4] flutter test --no-pub test/widgets/"
flutter test --no-pub test/widgets/

echo "==> [4/4] flutter test --no-pub test/golden/"
flutter test --no-pub test/golden/

echo
echo "✅ UI consistency check passed"
