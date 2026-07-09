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

## What The Smoke Run Verifies

- the app launches through the file-backed plain editor path
- the default source file opens
- the top command bar is present
- the editor font controls are mounted and report their persisted settings
- the bottom status bar is present
- the editor stays visible long enough for a screenshot capture
