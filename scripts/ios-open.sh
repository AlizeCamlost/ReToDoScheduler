#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/apps/mobile/ios_ng/Norn/Norn.xcodeproj"

usage() {
  cat <<'USAGE'
Usage: bash scripts/ios-open.sh

This helper only opens the current Norn Xcode project.
Primary workflow remains opening apps/mobile/ios_ng/Norn/Norn.xcodeproj in Xcode manually.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "[ios-open] Expected Xcode project not found: $PROJECT_PATH" >&2
  exit 1
fi

echo "[ios-open] Opening Norn Xcode project..."
open "$PROJECT_PATH"
echo "[ios-open] Opened ${PROJECT_PATH}"
