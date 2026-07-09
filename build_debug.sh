#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCHEME="${SCHEME:-SwiftlyCodeEdit}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
APP_PATH="${APP_PATH:-$REPO_ROOT/.build/$BUILD_CONFIGURATION/SwiftlyCodeEdit}"
# This build-verification launch is a self-quitting backstop, not a workspace to
# keep open. --kill-after keeps builds from piling up stray instances in the
# Dock and from contaminating the shared /tmp/codeedit_runtime.log marker counts.
LAUNCH_KILL_AFTER_SECONDS="${LAUNCH_KILL_AFTER_SECONDS:-5}"

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

echo "Building debug $SCHEME"
swift build --disable-sandbox -c "$BUILD_CONFIGURATION" &
build_pid="$!"
wait "$build_pid"
build_status="$?"
build_pid=""
trap - INT TERM EXIT

if [ "$build_status" -ne 0 ]; then
  exit "$build_status"
fi

echo "Launching $APP_PATH (auto-quits after ${LAUNCH_KILL_AFTER_SECONDS}s)"
"$APP_PATH" "--kill-after=$LAUNCH_KILL_AFTER_SECONDS" &
