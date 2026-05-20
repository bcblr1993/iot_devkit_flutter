#!/usr/bin/env bash
# scripts/ui_golden_update.sh
#
# 刷新 golden 基线 PNG。仅在你确认 Lab 组件外观“本该如此变化”时使用。
#
# 用法：
#   ./scripts/ui_golden_update.sh                 # 刷新全部 golden
#   ./scripts/ui_golden_update.sh lab_buttons     # 只刷新某个文件
#
# ⚠️  刷完务必：
#   1) 人工肉眼比对 test/golden/goldens/*.png 是否符合预期
#   2) commit message 注明刷新原因（比如“调整 LabButton hPad”）
#   3) 不要在 CI 上跑这个脚本

set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:-}"
if [[ -n "$target" ]]; then
  path="test/golden/${target}_golden_test.dart"
  echo "==> Updating golden for: $path"
  flutter test --no-pub --update-goldens "$path"
else
  echo "==> Updating all goldens under test/golden/"
  flutter test --no-pub --update-goldens test/golden/
fi

echo
echo "✅ goldens updated — please diff & review test/golden/goldens/*.png before committing"
