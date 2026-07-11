# Developer Usage Guide

This repository is driven by a small set of scripts. Use these first.

## Build

- `./build_debug.sh`
- `./build_release.sh`

## Package a .app bundle

- `./scripts/make_app_bundle.sh` (defaults to a release build)
- `./scripts/make_app_bundle.sh debug` builds and packages the debug binary instead
- Produces `build/SwiftlyCodeEdit.app` with the icon and Info.plist wired, so
  Finder, Dock, and the menu bar show the SwiftlyCodeEdit name and icon
- `build/` is gitignored; rerun the script any time the binary changes

## Smoke

- `./scripts/plain_editor_smoke.sh`
- Captures runtime logs in `/tmp/codeedit_runtime.log`
- Captures the app launch log in `/tmp/codeedit_plain_editor_smoke.log`
- Saves a screenshot artifact to `docs/screenshots/codeedit_window.png` when `~/nsh/easy-screenshot/run.sh` is available

## Benchmark syntax highlighting

- `./scripts/highlight_benchmark.sh`
- Runs the Kate interpreter cold-pass Swift test and prints per-stage
  `HIGHLIGHT_BENCH_STAGES` timings (`parseMs`/`interpretMs`/`spanMapMs`) alongside the
  overall `HIGHLIGHT_BENCH` totals line
- Writes the parsed timings to `test-results/perf/highlight_cold_pass.txt`

## Inspect

- `./show_app_jobs.sh`
- Shows the running `CodeEdit` process and system uptime

## Useful Environment Overrides

- `APP_PATH` to point a script at a different built app
- `BUILD_CONFIGURATION` to switch between `debug` and `release`
- `SOURCE_FILE` to change the file opened by the smoke script
- `LOG_FILE` and `RUNTIME_LOG` to change log destinations

## Typical Plain-Editor Loop

1. Run `./build_debug.sh`
2. Run `./scripts/plain_editor_smoke.sh`
3. Check `/tmp/codeedit_runtime.log`
4. Inspect `docs/screenshots/codeedit_window.png`

## Regenerate screenshots

- `./scripts/capture_screenshots.sh`
- Regenerates all `docs/screenshots/` PNGs in one command: five live
  on-screen window captures (the representative default-source window, plus
  varied-token and backdrop-differential fixtures under
  `tests/fixtures/screenshots/`), with light/dark appearance forced via
  `-AppleInterfaceStyle` and a fixed 15pt font
- Serializes each launch (`pkill`/`pgrep` before and after) so no capture
  races a prior instance
- `scripts/check_screenshot_not_black.py` gates each capture against a
  near-black mean-brightness floor, so a slept-or-locked-display capture is
  skipped rather than silently overwriting a good tracked PNG
- Also regenerates the app-icon preview via `scripts/make_app_icon.py`

## What The Smoke Run Verifies

- the app launches through the file-backed plain editor path
- the default source file opens
- the native toolbar is present
- the bottom status bar is present
- the editor stays visible long enough for a screenshot capture
