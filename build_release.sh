#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCHEME="${SCHEME:-SwiftlyCodeEdit}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
APP_PATH="${APP_PATH:-$REPO_ROOT/.build/$BUILD_CONFIGURATION/SwiftlyCodeEdit}"
INSTALL_TO_APPLICATIONS="${INSTALL_TO_APPLICATIONS:-0}"

cd "$REPO_ROOT"

export TMPDIR="${TMPDIR:-$REPO_ROOT/.tmp}"
BUILD_CACHE_ROOT="$(mktemp -d "$REPO_ROOT/.tmp/build-cache.XXXXXX")"
export CLANG_MODULE_CACHE_PATH="$BUILD_CACHE_ROOT/clang-modulecache"
export SWIFT_MODULECACHE_PATH="$BUILD_CACHE_ROOT/clang-modulecache"
export SWIFTPM_CONFIG_DIR="$BUILD_CACHE_ROOT/swiftpm-config"
export SWIFTPM_SECURITY_DIR="$BUILD_CACHE_ROOT/swiftpm-security"
export HOME="$BUILD_CACHE_ROOT/home"

mkdir -p \
  "$TMPDIR" \
  "$CLANG_MODULE_CACHE_PATH" \
  "$SWIFTPM_CONFIG_DIR" \
  "$SWIFTPM_SECURITY_DIR" \
  "$HOME" \
  "$REPO_ROOT/.build/artifacts"

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
