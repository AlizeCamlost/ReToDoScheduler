#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE_DIR="${ROOT_DIR}/apps/mobile"

DO_INSTALL=1
DO_PREBUILD=0
DO_OPEN_XCODE=0
RUN_METRO=1
USE_TUNNEL=0

usage() {
  cat <<'USAGE'
Usage: bash scripts/ios-dev.sh [options]

Options:
  --skip-install   Skip npm install
  --prebuild       Run iOS prebuild (regenerate native ios project)
  --open-xcode     Open ios/ReToDoScheduler.xcworkspace
  --no-metro       Do not start Metro after setup
  --tunnel         Start Metro in tunnel mode
  -h, --help       Show this help

Examples:
  bash scripts/ios-dev.sh
  bash scripts/ios-dev.sh --tunnel
  bash scripts/ios-dev.sh --prebuild --open-xcode --no-metro
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-install)
      DO_INSTALL=0
      ;;
    --prebuild)
      DO_PREBUILD=1
      ;;
    --open-xcode)
      DO_OPEN_XCODE=1
      ;;
    --no-metro)
      RUN_METRO=0
      ;;
    --tunnel)
      USE_TUNNEL=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

cd "$ROOT_DIR"

if [[ $DO_INSTALL -eq 1 ]]; then
  echo "[ios-dev] Installing dependencies..."
  npm install --no-audit --no-fund
fi

if [[ $DO_PREBUILD -eq 1 || ! -d "${MOBILE_DIR}/ios" ]]; then
  echo "[ios-dev] Running iOS prebuild..."
  NPM_CONFIG_REGISTRY="${NPM_CONFIG_REGISTRY:-https://registry.npmjs.org/}" \
    npm --prefix "$MOBILE_DIR" run prebuild:ios
fi

if [[ $DO_OPEN_XCODE -eq 1 ]]; then
  echo "[ios-dev] Opening Xcode workspace..."
  npm --prefix "$MOBILE_DIR" run open:xcode
fi

if [[ $RUN_METRO -eq 1 ]]; then
  echo "[ios-dev] Starting Metro..."
  if [[ $USE_TUNNEL -eq 1 ]]; then
    npm --prefix "$MOBILE_DIR" run dev -- --tunnel
  else
    npm --prefix "$MOBILE_DIR" run dev
  fi
fi

echo "[ios-dev] Done."
