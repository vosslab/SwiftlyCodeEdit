#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
APP_PATH="${APP_PATH:-$REPO_ROOT/.build/debug/SwiftlyCodeEdit}"
LOG_FILE="${LOG_FILE:-/tmp/codeedit_plain_editor_smoke.log}"
RUNTIME_LOG="${RUNTIME_LOG:-/tmp/codeedit_runtime.log}"
SOURCE_TEMPLATE="${SOURCE_TEMPLATE:-$REPO_ROOT/CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift}"
SOURCE_FILE="${SOURCE_FILE:-${TMPDIR:-/tmp}/codeedit_plain_editor_smoke_source.swift}"
RESULTS_DIR="${RESULTS_DIR:-$REPO_ROOT/test-results/plain_editor_smoke}"
SCREENSHOT_FILE="${SCREENSHOT_FILE:-$REPO_ROOT/docs/screenshots/codeedit_window.png}"
# Validation-only backstop: keeps the launched app from lingering in the Dock
# even if this script is interrupted before its own kill below runs. This
# backstop assumes the 2 s autosave debounce has already cleared dirty state
# well before the 60 s mark, so NSApp.terminate does not race a pending save.
APP_KILL_AFTER_SECONDS="${APP_KILL_AFTER_SECONDS:-60}"

NO_SCREENSHOT=0
for arg in "$@"; do
  case "$arg" in
    --no-screenshot)
      NO_SCREENSHOT=1
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT"

mkdir -p "$RESULTS_DIR" "$(dirname "$SCREENSHOT_FILE")"

# Stale artifacts from a prior run must not leak into this run's evidence, so
# every run starts from a clean slate. SCREENSHOT_FILE is git-tracked and is
# only removed later, right before a run that will actually regenerate it.
rm -f "$LOG_FILE" "$RUNTIME_LOG" "$SOURCE_FILE"

cp "$SOURCE_TEMPLATE" "$SOURCE_FILE"
pkill -x SwiftlyCodeEdit 2>/dev/null || true
: >"$LOG_FILE"
: >"$RUNTIME_LOG"
CODEEDIT_DEBUG_SOURCE_FILE="$SOURCE_FILE" \
CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST=1 \
"$APP_PATH" "--kill-after=$APP_KILL_AFTER_SECONDS" >"$LOG_FILE" 2>&1 &
APP_PID="$!"

cleanup() {
  if kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
}

# Callers should never need redirection to learn the result: report the
# script's own final exit status to stderr on every exit path, success or
# failure.
report_exit() {
  local exit_code="$?"
  cleanup
  echo "SMOKE_EXIT=$exit_code" >&2
}
trap report_exit EXIT

sleep 3

# Hard gates: every one of these lines must appear or the run fails. Each
# proves a required stage of launch, document load, or editor readiness.
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
wait_for_line "LAUNCH_TO_WINDOW_MS="
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

# Optional diagnostic: screenshot capture depends on machine-local tooling and
# the macOS screen-recording TCC grant, neither of which is a repo bug. A
# missing helper or a denied grant is reported and skipped, not a hard failure.
if [ "$NO_SCREENSHOT" -eq 1 ]; then
  echo "SKIPPED: screenshot capture disabled by --no-screenshot"
elif [ ! -x "$HOME/nsh/easy-screenshot/run.sh" ]; then
  echo "SKIPPED: screenshot capture, missing helper $HOME/nsh/easy-screenshot/run.sh"
else
  # Only remove the git-tracked screenshot on the branch that will actually
  # regenerate it, so a SKIPPED run leaves the tracked file untouched.
  rm -f "$SCREENSHOT_FILE"
  "$HOME/nsh/easy-screenshot/run.sh" \
    -A SwiftlyCodeEdit \
    -t "$(basename "$SOURCE_FILE")" \
    -f "$SCREENSHOT_FILE" >>"$RUNTIME_LOG" 2>&1 || true
  if [ -s "$SCREENSHOT_FILE" ]; then
    echo "Screenshot captured: $SCREENSHOT_FILE" >>"$RUNTIME_LOG"
    wait_for_line "Screenshot captured: $SCREENSHOT_FILE"
    # Hard gate: a captured screenshot showing plain unhighlighted text must
    # fail the smoke run, not pass silently.
    python3 tests/e2e/e2e_screenshot_colors.py "$SCREENSHOT_FILE"
  else
    echo "SKIPPED: screenshot capture, helper ran but produced no file (likely denied screen-recording permission)"
  fi
fi

cleanup

cp "$LOG_FILE" "$RESULTS_DIR/app.log"
cp "$RUNTIME_LOG" "$RESULTS_DIR/runtime.log"

echo "Plain editor smoke passed"
