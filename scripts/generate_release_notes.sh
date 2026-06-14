#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-dist/release-notes.md}"
REPO="${GITHUB_REPOSITORY:-bcblr1993/iot_devkit_flutter}"
CURRENT_TAG="${GITHUB_REF_NAME:-}"

mkdir -p "$(dirname "$OUT")"

if [[ -z "$CURRENT_TAG" ]]; then
  CURRENT_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi

if [[ -z "$CURRENT_TAG" ]]; then
  echo "Cannot determine current release tag." >&2
  exit 1
fi

if [[ "$CURRENT_TAG" != v* ]]; then
  CURRENT_TAG="v${CURRENT_TAG}"
fi

MANUAL_NOTES="docs/releases/${CURRENT_TAG}.md"

git fetch --tags --force >/dev/null 2>&1 || true

PREVIOUS_TAG="$(
  git tag --sort=-version:refname |
    awk -v current="$CURRENT_TAG" '
      $0 ~ /^v/ {
        if (seen) {
          print
          exit
        }
        if ($0 == current) {
          seen = 1
        }
      }
    '
)"

if [[ -z "$PREVIOUS_TAG" ]]; then
  PREVIOUS_TAG="$(
    git tag --sort=-version:refname |
      grep '^v' |
      grep -F -v -x "$CURRENT_TAG" |
      head -n 1 || true
  )"
fi

COMPARE_LABEL=""
COMPARE_URL=""
if [[ -n "$PREVIOUS_TAG" ]]; then
  COMPARE_LABEL="${PREVIOUS_TAG}...${CURRENT_TAG}"
  COMPARE_URL="https://github.com/${REPO}/compare/${PREVIOUS_TAG}...${CURRENT_TAG}"
fi

if [[ -f "$MANUAL_NOTES" ]]; then
  cp "$MANUAL_NOTES" "$OUT"
  if [[ -n "$COMPARE_URL" ]] && ! grep -q "完整更新日志" "$OUT"; then
    {
      printf '\n'
      printf '**完整更新日志：** [%s](%s)\n' "$COMPARE_LABEL" "$COMPARE_URL"
    } >> "$OUT"
  fi
  exit 0
fi

range="$CURRENT_TAG"
if [[ -n "$PREVIOUS_TAG" ]]; then
  range="${PREVIOUS_TAG}..${CURRENT_TAG}"
fi

features=()
fixes=()
optimizations=()
verification=()
changes=()

clean_subject() {
  local subject="$1"

  subject="$(printf '%s' "$subject" | sed -E 's/^[^[:alnum:]]+[[:space:]]*//')"
  subject="$(printf '%s' "$subject" | sed -E 's/^[a-zA-Z]+(\([^)]+\))?:[[:space:]]*//')"
  subject="$(printf '%s' "$subject" | sed -E 's/^发布[[:space:]]+v[0-9][^[:space:]]*[[:space:]]*//')"

  printf '%s' "$subject"
}

while IFS= read -r subject || [[ -n "$subject" ]]; do
  [[ -z "$subject" ]] && continue

  item="$(clean_subject "$subject")"
  [[ -z "$item" ]] && item="$subject"

  case "$subject" in
    *feat*|*新增*|*支持*)
      features+=("$item")
      ;;
    *fix*|*修复*|*问题*)
      fixes+=("$item")
      ;;
    *test*|*ci*|*build*|*验证*|*测试*)
      verification+=("$item")
      ;;
    *refactor*|*style*|*ui*|*优化*|*重构*|*release*|*发布*)
      optimizations+=("$item")
      ;;
    *)
      changes+=("$item")
      ;;
  esac
done < <(git log --pretty=format:'%s' "$range")

write_section() {
  local title="$1"
  shift
  local items=("$@")

  [[ "${#items[@]}" -eq 0 ]] && return

  printf '## %s\n\n' "$title" >> "$OUT"
  for item in "${items[@]}"; do
    printf -- '- %s。\n' "$item" >> "$OUT"
  done
  printf '\n' >> "$OUT"
}

: > "$OUT"

# Use the ${arr[@]+"${arr[@]}"} idiom so empty arrays expand to nothing under
# `set -u` — macOS runners ship bash 3.2, which otherwise errors with
# "unbound variable" when a release has no commits in a given category.
write_section "新增" ${features[@]+"${features[@]}"}
write_section "修复" ${fixes[@]+"${fixes[@]}"}
write_section "优化" ${optimizations[@]+"${optimizations[@]}"} ${changes[@]+"${changes[@]}"}

{
  printf '## 验证\n\n'
  if [[ "${#verification[@]}" -gt 0 ]]; then
    for item in "${verification[@]}"; do
      printf -- '- %s。\n' "$item"
    done
  fi
  printf -- '- 已执行 GitHub Actions 发布流水线中的 Flutter 测试和对应平台构建。\n'
  printf -- '- 发布产物会附带 macOS、Windows 和 Linux 安装包/压缩包。\n'
  printf '\n'

  if [[ -n "$COMPARE_URL" ]]; then
    printf '**完整更新日志：** [%s](%s)\n' "$COMPARE_LABEL" "$COMPARE_URL"
  fi
} >> "$OUT"
