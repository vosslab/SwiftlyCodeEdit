#!/usr/bin/env bash
set -euo pipefail

# Regenerates every file in docs/screenshots/ from the current build: seven
# live on-screen window captures (default source, light/dark varied-token
# chrome, the two backdrop-differential fixtures, and the two reduced-
# transparency fixtures) plus the programmatic app icon preview. Run with:
# bash scripts/capture_screenshots.sh

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

APP_PATH="$REPO_ROOT/.build/debug/SwiftlyCodeEdit"
RUNTIME_LOG="/tmp/codeedit_runtime.log"
CAPTURE_LOG="/tmp/codeedit_capture_screenshots.log"
SCREENSHOTS_DIR="$REPO_ROOT/docs/screenshots"
FIXTURES_DIR="$REPO_ROOT/tests/fixtures/screenshots"
MAIN_WINDOW_TEMPLATE="$REPO_ROOT/CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift"
VARIED_TOKENS_FIXTURE="$REPO_ROOT/tests/fixtures/syntax_smoke_sample.swift"
COMMENT_HEAVY_FIXTURE="$FIXTURES_DIR/comment_heavy_top.swift"
STRING_HEAVY_FIXTURE="$FIXTURES_DIR/string_heavy_top.swift"
APP_KILL_AFTER_SECONDS="${APP_KILL_AFTER_SECONDS:-25}"

mkdir -p "$SCREENSHOTS_DIR"
: >"$CAPTURE_LOG"

SCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codeedit_capture_screenshots.XXXXXX")"
# Copied rather than opened in place, so this evidence run never touches a
# tracked source file even if the app's autosave path were ever triggered.
MAIN_WINDOW_SOURCE="$SCRATCH_DIR/codeedit_window_source.swift"
cp "$MAIN_WINDOW_TEMPLATE" "$MAIN_WINDOW_SOURCE"

REGENERATED=()
SKIPPED=()

# A prior agent left a stray instance running and caused a flaky test; this
# trap guarantees no launched instance outlives this script, success or not.
cleanup() {
  pkill -x SwiftlyCodeEdit 2>/dev/null || true
  rm -rf "$SCRATCH_DIR"
}
trap cleanup EXIT

# Rebuild the debug binary if it is missing or older than any tracked Swift
# source, so the captured chrome always reflects the current code.
needs_build=0
if [ ! -x "$APP_PATH" ]; then
  needs_build=1
elif [ -n "$(find "$REPO_ROOT/CodeEdit" "$REPO_ROOT/Packages" "$REPO_ROOT/Package.swift" \
    -newer "$APP_PATH" -type f -print -quit 2>/dev/null)" ]; then
  needs_build=1
fi
if [ "$needs_build" -eq 1 ]; then
  echo "Rebuilding: $APP_PATH is missing or older than the Swift sources"
  "$REPO_ROOT/build_debug.sh"
fi

# Launches one window over source_file, waits for it to render, captures it
# to a /tmp scratch file, and only overwrites the tracked PNG after
# confirming the scratch capture is non-empty and not near-black. A capture
# taken while the display is asleep or locked is a non-fatal skip, not a
# script failure, so the tracked PNG from the previous run stays untouched.
capture_window() {
  local source_file="$1"
  local appearance="$2"
  local output_file="$3"
  local label="$4"
  local reduce_transparency="${5:-}"

  pkill -x SwiftlyCodeEdit 2>/dev/null || true
  local stop_attempts=0
  while pgrep -x SwiftlyCodeEdit >/dev/null 2>&1 && [ "$stop_attempts" -lt 10 ]; do
    sleep 0.2
    stop_attempts=$((stop_attempts + 1))
  done
  : >"$RUNTIME_LOG"

  local window_title
  window_title="$(basename "$source_file")"

  local -a appearance_args=()
  if [ -n "$appearance" ]; then
    appearance_args=(-AppleInterfaceStyle "$appearance")
  fi

  local -a reduce_transparency_args=()
  if [ "$reduce_transparency" = "1" ]; then
    reduce_transparency_args=(-PlainEditor.forceReduceTransparency YES)
  fi

  CODEEDIT_DEBUG_SOURCE_FILE="$source_file" \
    "$APP_PATH" "--kill-after=$APP_KILL_AFTER_SECONDS" \
    "${appearance_args[@]}" \
    "${reduce_transparency_args[@]}" \
    -PlainEditor.fontSize 14 \
    >>"$CAPTURE_LOG" 2>&1 &
  local app_pid="$!"

  local start_attempts=0
  while ! pgrep -x SwiftlyCodeEdit >/dev/null 2>&1 && [ "$start_attempts" -lt 10 ]; do
    sleep 0.2
    start_attempts=$((start_attempts + 1))
  done

  local ready_attempts=0
  while [ "$ready_attempts" -lt 10 ]; do
    if grep -F "Plain editor toolbar ready" "$RUNTIME_LOG" >/dev/null 2>&1; then
      break
    fi
    ready_attempts=$((ready_attempts + 1))
    sleep 1
  done
  # Extra settle time after the readiness marker so the window has finished
  # its first paint before the on-screen capture runs.
  sleep 1

  local scratch_png
  scratch_png="$(mktemp "$SCRATCH_DIR/capture.XXXXXX.png")"
  "$HOME/nsh/easy-screenshot/run.sh" \
    -A SwiftlyCodeEdit \
    -t "$window_title" \
    -f "$scratch_png" >>"$CAPTURE_LOG" 2>&1 || true

  if [ -s "$scratch_png" ] \
      && python3 "$REPO_ROOT/scripts/check_screenshot_not_black.py" -i "$scratch_png" >>"$CAPTURE_LOG" 2>&1; then
    mv "$scratch_png" "$output_file"
    echo "REGENERATED: $output_file ($label)"
    REGENERATED+=("$output_file")
  else
    rm -f "$scratch_png"
    echo "SKIPPED: $output_file ($label) -- capture empty or near-black (display asleep or locked?)"
    SKIPPED+=("$output_file")
  fi

  if kill -0 "$app_pid" 2>/dev/null; then
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
}

if [ ! -x "$HOME/nsh/easy-screenshot/run.sh" ]; then
  echo "SKIPPED: all window captures, missing helper $HOME/nsh/easy-screenshot/run.sh"
  SKIPPED+=(
    "$SCREENSHOTS_DIR/codeedit_window.png"
    "$SCREENSHOTS_DIR/glass_toolbar_light.png"
    "$SCREENSHOTS_DIR/glass_toolbar_dark.png"
    "$SCREENSHOTS_DIR/glass_backdrop_green_light.png"
    "$SCREENSHOTS_DIR/glass_backdrop_red_light.png"
    "$SCREENSHOTS_DIR/glass_statusbar_reduced_light.png"
    "$SCREENSHOTS_DIR/glass_statusbar_reduced_dark.png"
  )
else
  capture_window "$MAIN_WINDOW_SOURCE" "" \
    "$SCREENSHOTS_DIR/codeedit_window.png" "main window, representative source"
  capture_window "$VARIED_TOKENS_FIXTURE" "Light" \
    "$SCREENSHOTS_DIR/glass_toolbar_light.png" "varied tokens, light"
  capture_window "$VARIED_TOKENS_FIXTURE" "Dark" \
    "$SCREENSHOTS_DIR/glass_toolbar_dark.png" "varied tokens, dark"
  capture_window "$COMMENT_HEAVY_FIXTURE" "Light" \
    "$SCREENSHOTS_DIR/glass_backdrop_green_light.png" "comment-dominated, light"
  capture_window "$STRING_HEAVY_FIXTURE" "Light" \
    "$SCREENSHOTS_DIR/glass_backdrop_red_light.png" "string-dominated, light"
  capture_window "$VARIED_TOKENS_FIXTURE" "Light" \
    "$SCREENSHOTS_DIR/glass_statusbar_reduced_light.png" "varied tokens, reduced transparency, light" \
    "1"
  capture_window "$VARIED_TOKENS_FIXTURE" "Dark" \
    "$SCREENSHOTS_DIR/glass_statusbar_reduced_dark.png" "varied tokens, reduced transparency, dark" \
    "1"
fi

# The app icon is drawn programmatically rather than captured from a window.
echo "Regenerating app icon preview via scripts/make_app_icon.py"
source "$REPO_ROOT/source_me.sh"
python3 "$REPO_ROOT/scripts/make_app_icon.py"
REGENERATED+=("$SCREENSHOTS_DIR/app_icon_preview.png")

echo ""
echo "Summary:"
echo "  regenerated: ${#REGENERATED[@]}"
for path in "${REGENERATED[@]}"; do
  echo "    - $path"
done
echo "  skipped: ${#SKIPPED[@]}"
for path in "${SKIPPED[@]}"; do
  echo "    - $path"
done
