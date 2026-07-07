#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
APP_PATH="${APP_PATH:-$REPO_ROOT/.build/debug/CodeEdit}"
LOG_FILE="${LOG_FILE:-/tmp/codeedit_plain_editor_smoke.log}"
RUNTIME_LOG="${RUNTIME_LOG:-/tmp/codeedit_runtime.log}"
SOURCE_FILE="${SOURCE_FILE:-$REPO_ROOT/CodeEdit/CodeEditApp.swift}"

cd "$REPO_ROOT"

: >"$LOG_FILE"
: >"$RUNTIME_LOG"
"$APP_PATH" >"$LOG_FILE" 2>&1 &
APP_PID="$!"

cleanup() {
  if kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

sleep 3

wait_for_line() {
  local needle="$1"
  local attempts=0
  while [ "$attempts" -lt 10 ]; do
    if grep -F "$needle" "$RUNTIME_LOG" >/dev/null 2>&1; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 1
  done
  echo "Missing runtime log line: $needle" >&2
  cat "$RUNTIME_LOG" >&2
  return 1
}

wait_for_line "Plain editor launch path ready"
wait_for_line "Loaded document: $SOURCE_FILE"
wait_for_line "Loaded file: $SOURCE_FILE"
wait_for_line "Created editor window for $SOURCE_FILE"
wait_for_line "PlainTextEditorView created"
wait_for_line "PlainTextEditorView requested first responder"

kill "$APP_PID" 2>/dev/null || true
wait "$APP_PID" 2>/dev/null || true
trap - EXIT

echo "Plain editor smoke passed"
