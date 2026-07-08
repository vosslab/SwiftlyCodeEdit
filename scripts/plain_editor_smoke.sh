#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
APP_PATH="${APP_PATH:-$REPO_ROOT/.build/debug/CodeEdit}"
LOG_FILE="${LOG_FILE:-/tmp/codeedit_plain_editor_smoke.log}"
RUNTIME_LOG="${RUNTIME_LOG:-/tmp/codeedit_runtime.log}"
SOURCE_TEMPLATE="${SOURCE_TEMPLATE:-$REPO_ROOT/CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift}"
SOURCE_FILE="${SOURCE_FILE:-${TMPDIR:-/tmp}/codeedit_plain_editor_smoke_source.swift}"
RESULTS_DIR="${RESULTS_DIR:-$REPO_ROOT/test-results/plain_editor_smoke}"

cd "$REPO_ROOT"

mkdir -p "$RESULTS_DIR"
cp "$SOURCE_TEMPLATE" "$SOURCE_FILE"
pkill -x CodeEdit 2>/dev/null || true
: >"$LOG_FILE"
: >"$RUNTIME_LOG"
CODEEDIT_DEBUG_SOURCE_FILE="$SOURCE_FILE" \
CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST=1 \
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
wait_for_line "Plain editor command ribbon ready"
wait_for_line "Plain editor status bar ready"
wait_for_line "Plain editor status: cursor="
wait_for_line "encoding=UTF-8"
wait_for_line "lineEnding=LF"
wait_for_line "Plain editor Swift syntax highlight:"
wait_for_line "tokens=comment,keyword,number,string,type"
wait_for_line "colors=6"
wait_for_line "Plain editor command self-test: insert=true undo=true redo=true selectAll=true copy=true cut=true paste=true cleanText=true cleanUndo=true cleanRedo=true"
wait_for_line "Main menu items:"

if [ -x "$HOME/nsh/easy-screenshot/run.sh" ]; then
  if "$HOME/nsh/easy-screenshot/run.sh" --application CodeEdit --preview >>"$RUNTIME_LOG" 2>&1; then
    echo "Screenshot confirmation captured" >>"$RUNTIME_LOG"
    wait_for_line "Screenshot confirmation captured"
  else
    echo "Screenshot confirmation unavailable" >>"$RUNTIME_LOG"
  fi
fi

kill "$APP_PID" 2>/dev/null || true
wait "$APP_PID" 2>/dev/null || true
trap - EXIT

cp "$LOG_FILE" "$RESULTS_DIR/app.log"
cp "$RUNTIME_LOG" "$RESULTS_DIR/runtime.log"

echo "Plain editor smoke passed"
