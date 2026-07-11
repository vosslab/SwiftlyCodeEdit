# Install

Installed means having a working `SwiftlyCodeEdit.app` you can launch, built locally
from source with SwiftPM. There is no packaged distribution or installer; every user
builds the app themselves.

## Requirements

- macOS Tahoe (macOS 26) or newer, on Apple Silicon. `Package.swift` sets
  `platforms: [.macOS(.v26)]`.
- Swift tools version 6.3 or newer (the Swift toolchain that ships with a
  matching Xcode/Command Line Tools install). `Package.swift` declares
  `// swift-tools-version: 6.3`.
- `git`, to clone the repository.
- For the Python developer tooling only (icon generation, screenshot color
  checks, lint/test scripts): Homebrew Python 3.12, with modules installed to
  `/opt/homebrew/lib/python3.12/site-packages/`.

## Install steps

1. Clone the repository and change into it:
   ```bash
   git clone <repo-url> SwiftlyCodeEdit
   cd SwiftlyCodeEdit
   ```
2. Build and launch a debug build in one step:
   ```bash
   ./build_debug.sh
   ```
   This runs `swift build --disable-sandbox -c debug` and then launches the
   resulting binary at `.build/debug/SwiftlyCodeEdit`.
3. For a release build instead:
   ```bash
   ./build_release.sh
   ```
   Set `INSTALL_TO_APPLICATIONS=1` to also copy the built binary to
   `/Applications`:
   ```bash
   INSTALL_TO_APPLICATIONS=1 ./build_release.sh
   ```
4. To produce a double-clickable `.app` bundle with the icon and Info.plist
   wired up (Finder, Dock, and menu bar all show the SwiftlyCodeEdit name):
   ```bash
   ./scripts/make_app_bundle.sh
   ```
   Pass `debug` as an argument to package the debug binary instead of the
   release default:
   ```bash
   ./scripts/make_app_bundle.sh debug
   ```
   This writes `build/SwiftlyCodeEdit.app` (gitignored; rerun the script any
   time the underlying binary changes).
5. Python developer tooling (only needed for icon regeneration, screenshot
   color checks, and repo lint/test scripts) uses the repo's bootstrap
   pattern and its own dependency manifest:
   ```bash
   source source_me.sh && python3 -m pip install -r pip_requirements-dev.txt
   ```

## Verify install

Run the smoke script, which launches the debug build, opens a source file
through the plain-editor path, and confirms the toolbar, editor, and
status bar all appear:

```bash
./scripts/plain_editor_smoke.sh
```

A successful run prints `SMOKE_EXIT=0` to stderr. See
[docs/DEVELOPER_USAGE.md](DEVELOPER_USAGE.md) for the full script reference,
including log locations and environment overrides (`APP_PATH`,
`BUILD_CONFIGURATION`, `SOURCE_FILE`, `LOG_FILE`, `RUNTIME_LOG`).

## Known gaps

- [ ] Confirm the minimum Xcode/Command Line Tools version that ships Swift
  tools 6.3, and record it here.
- [ ] Confirm whether Intel Macs are unsupported or merely untested (the
  `platforms` entry only names `.macOS(.v26)`, with no architecture
  restriction recorded in `Package.swift`).
