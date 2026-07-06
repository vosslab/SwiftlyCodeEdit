#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCHEME="${SCHEME:-CodeEdit}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
APP_PATH="${APP_PATH:-$REPO_ROOT/.build/$BUILD_CONFIGURATION/CodeEdit}"
INSTALL_TO_APPLICATIONS="${INSTALL_TO_APPLICATIONS:-0}"

cd "$REPO_ROOT"

build_pid=""
cleanup() {
  if [ -n "$build_pid" ] && kill -0 "$build_pid" 2>/dev/null; then
    kill -INT "$build_pid" 2>/dev/null || true
    wait "$build_pid" 2>/dev/null || true
  fi
}
trap cleanup INT TERM EXIT

echo "Building release $SCHEME"
swift build --disable-sandbox -c "$BUILD_CONFIGURATION" &
build_pid="$!"
wait "$build_pid"
build_status="$?"
build_pid=""
trap - INT TERM EXIT

if [ "$build_status" -ne 0 ]; then
  exit "$build_status"
fi

echo "Built app at $APP_PATH"

if [ "$INSTALL_TO_APPLICATIONS" = "1" ]; then
  echo "Copying to /Applications"
  cp -R "$APP_PATH" /Applications/
fi
