#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/apps/mobile/ios/ReToDoScheduler.xcodeproj"

usage() {
  cat <<'USAGE'
Usage: bash scripts/ios-dev.sh

This project now uses a native SwiftUI iOS app.
The script simply opens the Xcode project.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

echo "[ios-dev] Opening native iOS project..."
open "$PROJECT_PATH"
echo "[ios-dev] Opened ${PROJECT_PATH}"
