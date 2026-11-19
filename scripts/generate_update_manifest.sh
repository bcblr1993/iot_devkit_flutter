#!/usr/bin/env bash
set -euo pipefail

DIST_DIR="${1:-dist}"
NOTES_FILE="${2:-dist/release-notes.md}"
OUT_MANIFEST="${3:-dist/latest.json}"
OUT_SUMS="${4:-dist/SHA256SUMS.txt}"
REQUIRE_ALL="${REQUIRE_ALL_PLATFORMS:-false}"

REPO="${GITHUB_REPOSITORY:-bcblr1993/iot_devkit_flutter}"
CURRENT_TAG="${GITHUB_REF_NAME:-}"

if [[ -z "$CURRENT_TAG" ]]; then
  CURRENT_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi

if [[ -z "$CURRENT_TAG" ]]; then
  RAW_PUBSPEC_VER="$(grep '^version: ' pubspec.yaml | head -n 1 | sed 's/version: //' | cut -d+ -f1 | tr -d '[:space:]')"
  CURRENT_TAG="v${RAW_PUBSPEC_VER}"
fi

if [[ "$CURRENT_TAG" != v* ]]; then
  CURRENT_TAG="v${CURRENT_TAG}"
fi

mkdir -p "$(dirname "$OUT_MANIFEST")"
mkdir -p "$(dirname "$OUT_SUMS")"

python3 - "$DIST_DIR" "$NOTES_FILE" "$OUT_MANIFEST" "$OUT_SUMS" "$REPO" "$CURRENT_TAG" "$REQUIRE_ALL" <<'PY'
import datetime
import hashlib
import json
import os
import re
import sys

dist_dir, notes_file, out_manifest, out_sums, repo, tag, require_all_raw = sys.argv[1:8]
require_all = require_all_raw.strip().lower() in ("1", "true", "yes")

raw_ver = tag[1:] if tag.startswith(("v", "V")) else tag
raw_ver = raw_ver.split("+", 1)[0]
version = re.sub(r"-20\d{6}$", "", raw_ver)

notes = ""
if os.path.isfile(notes_file):
    with open(notes_file, "r", encoding="utf-8") as fh:
        notes = fh.read().strip()

def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def detect_platform(filename: str):
    lower = filename.lower()
    if lower in ("latest.json", "sha256sums.txt", "release-notes.md") or lower.endswith(".sha256"):
        return None
    if lower.endswith(".dmg"):
        return "macos"
    if lower.endswith(".exe") or lower.endswith(".msi"):
        return "windows"
    if lower.endswith(".tar.gz") or lower.endswith(".deb") or lower.endswith(".appimage"):
        return "linux"
    return None

candidates = []
if os.path.isdir(dist_dir):
    for root, _, files in os.walk(dist_dir):
        for fname in sorted(files):
            platform = detect_platform(fname)
            if platform is not None:
                candidates.append((platform, fname, os.path.join(root, fname)))

platforms = {}
checksum_rows = []
for platform, fname, fpath in candidates:
    digest = sha256_file(fpath)
    size = os.path.getsize(fpath)
    download_url = f"https://github.com/{repo}/releases/download/{tag}/{fname}"
    platforms[platform] = {
        "name": fname,
        "url": download_url,
        "sha256": digest,
        "size": size,
    }
    checksum_rows.append((digest, fname))

if require_all:
    missing = [p for p in ("macos", "windows", "linux") if p not in platforms]
    if missing:
        sys.stderr.write(f"Error: missing platform artifacts for: {', '.join(missing)}\n")
        sys.exit(1)

published_at = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
manifest = {
    "version": version,
    "tag": tag,
    "publishedAt": published_at,
    "htmlUrl": f"https://github.com/{repo}/releases/tag/{tag}",
    "prerelease": "-" in version,
    "notes": notes,
    "platforms": platforms,
}

with open(out_manifest, "w", encoding="utf-8") as fh:
    json.dump(manifest, fh, ensure_ascii=False, indent=2)
    fh.write("\n")

with open(out_sums, "w", encoding="utf-8") as fh:
    for digest, fname in checksum_rows:
        fh.write(f"{digest}  {fname}\n")

print(f"Generated {out_manifest} for {tag} (version={version}, platforms={list(platforms.keys())})")
PY
