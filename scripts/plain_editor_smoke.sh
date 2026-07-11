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
CODEEDIT_SETTINGS_APPLY_SELF_TEST=1 \
"$APP_PATH" "--kill-after=$APP_KILL_AFTER_SECONDS" \
  -PlainEditor.forceReduceTransparency YES \
  -PlainEditor.forceIncreaseContrast YES \
  >"$LOG_FILE" 2>&1 &
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

# Extracts one top-level menu's own bracketed item list from the "Main menu
# items:" line, anchored on a preceding "| " or start-of-line so a menu name
# that is a substring of another title (Edit inside "SwiftlyCodeEdit: [...]")
# can never match the wrong bracket group.
extract_menu_section() {
  local menu_name="$1"
  grep -oE "(^|\\| )${menu_name}: \\[[^]]*\\]" "$RUNTIME_LOG" | tail -1
}

# Hard gate: fails unless every first-party item named in the plan's menu
# inventory is present in the given menu's bracket section. macOS injects
# extra items (Writing Tools, AutoFill, Start Dictation, Emoji & Symbols,
# blank separators) that vary by OS version and are not checked here; only
# a missing first-party item fails the run.
check_menu_has_items() {
  local menu_name="$1"
  shift
  local section
  # `|| true` keeps `set -e` from short-circuiting past the diagnostic below
  # when extract_menu_section's grep finds nothing (grep exits non-zero on
  # no match, which would otherwise abort the script before the missing-
  # section message and log dump ever print).
  section="$(extract_menu_section "$menu_name")" || true
  if [ -z "$section" ]; then
    echo "Main menu items: missing menu section '$menu_name'" >&2
    cat "$RUNTIME_LOG" >&2
    return 1
  fi
  local item
  for item in "$@"; do
    local escaped_item
    escaped_item="$(printf '%s' "$item" | sed -E 's/([.[\*^$+?(){}|\\])/\\\1/g')"
    if ! echo "$section" | grep -E "(\\[|, )${escaped_item}(,|\\])" >/dev/null 2>&1; then
      echo "Main menu items: menu '$menu_name' missing expected item '$item'" >&2
      echo "$section" >&2
      return 1
    fi
  done
  return 0
}

wait_for_line "SHELL=SwiftUI"
wait_for_line "Plain editor launch path ready"
wait_for_line "Loaded document: $SOURCE_FILE"
wait_for_line "Loaded file: $SOURCE_FILE"
wait_for_line "Created editor window for $SOURCE_FILE"
wait_for_line "LAUNCH_TO_WINDOW_MS="
wait_for_line "PlainTextEditorView created"
wait_for_line "PlainTextEditorView requested first responder"
wait_for_line "Plain editor toolbar ready"
wait_for_line "Plain editor status bar ready"
wait_for_line "Plain editor status: cursor="
wait_for_line "encoding=UTF-8"
wait_for_line "lineEnding=LF"
wait_for_line "Plain editor Swift syntax highlight:"
wait_for_line "tokens=comment,keyword,number,string,type"
wait_for_line "colors=6"
wait_for_line "Plain editor command self-test: insert=true undo=true redo=true selectAll=true copy=true cut=true paste=true cleanText=true cleanUndo=true cleanRedo=true cleanLineEndings=true cleanFinalNewline=true cleanTabsToSpaces=true cleanSpacesToTabs=true cleanSmartPunct=true"
# Settings live-apply: the settings self-test performs a real post-mount font-size
# and theme change through the same @AppStorage path the Settings window uses,
# so both view-application markers must appear, then it restores the prior
# values (proving the seam persisted nothing to the user's preferences).
wait_for_line "SETTINGS_APPLIED key=fontSize"
wait_for_line "SETTINGS_APPLIED key=theme"
wait_for_line "SETTINGS_APPLY_SELF_TEST fontRestored=true themeRestored=true"
# Appearance markers: the app is launched with -PlainEditor.forceReduceTransparency YES and
# -PlainEditor.forceIncreaseContrast YES (NSArgumentDomain launch arguments, no
# `defaults write` against the real com.apple.universalaccess preferences), so
# the appearance marker must report both forced accessibility flags as set.
# The mode half (light/dark) reflects the real system appearance, which this
# script does not force, so only the accessibility-flag suffix is asserted.
wait_for_line "APPEARANCE_MODE="
wait_for_line "reduceTransparency=1 increaseContrast=1"
wait_for_line "Main menu items:"
check_menu_has_items "File" "New" "Open..." "Save" "Save As..." "Close"
check_menu_has_items "Edit" "Undo" "Redo" "Cut" "Copy" "Paste" "Select All" "Clean Text"
check_menu_has_items "Find" "Find..." "Find and Replace..."
check_menu_has_items "Format" "Font and Text Options"

# Optional diagnostic: screenshot capture depends on machine-local tooling and
# the macOS screen-recording TCC grant, neither of which is a repo bug. A
# missing helper or a denied grant is reported and skipped, not a hard failure.
if [ "$NO_SCREENSHOT" -eq 1 ]; then
  echo "SKIPPED: screenshot capture disabled by --no-screenshot"
elif [ ! -x "$HOME/nsh/easy-screenshot/run.sh" ]; then
  echo "SKIPPED: screenshot capture, missing helper $HOME/nsh/easy-screenshot/run.sh"
else
  # Capture to a scratch path first and only overwrite the git-tracked
  # screenshot with `mv` after a confirmed non-empty capture. A TCC-denied
  # or otherwise failed capture then leaves the tracked file untouched
  # instead of being deleted ahead of an attempt that produces nothing.
  SCREENSHOT_SCRATCH="$(mktemp "${TMPDIR:-/tmp}/codeedit_smoke_screenshot.XXXXXX.png")"
  "$HOME/nsh/easy-screenshot/run.sh" \
    -A SwiftlyCodeEdit \
    -t "$(basename "$SOURCE_FILE")" \
    -f "$SCREENSHOT_SCRATCH" >>"$RUNTIME_LOG" 2>&1 || true
  if [ -s "$SCREENSHOT_SCRATCH" ]; then
    mv "$SCREENSHOT_SCRATCH" "$SCREENSHOT_FILE"
    echo "Screenshot captured: $SCREENSHOT_FILE" >>"$RUNTIME_LOG"
    wait_for_line "Screenshot captured: $SCREENSHOT_FILE"
    # Hard gate: a captured screenshot showing plain unhighlighted text must
    # fail the smoke run, not pass silently.
    python3 tests/e2e/e2e_screenshot_colors.py "$SCREENSHOT_FILE"
  else
    rm -f "$SCREENSHOT_SCRATCH"
    echo "SKIPPED: screenshot capture, helper ran but produced no file (likely denied screen-recording permission)"
  fi
fi

cleanup

cp "$LOG_FILE" "$RESULTS_DIR/app.log"
cp "$RUNTIME_LOG" "$RESULTS_DIR/runtime.log"

echo "Plain editor smoke passed"
