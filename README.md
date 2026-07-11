# SwiftlyCodeEdit

A fast native plain-code editor for macOS 26, built for developers who want a lightweight SwiftUI-first alternative to heavyweight IDEs, with syntax highlighting that stays near-instant across hundreds of bundled language definitions.

SwiftlyCodeEdit is a hard fork of [CodeEdit](https://github.com/CodeEditApp/CodeEdit), stripped down to a focused plain-text and code editor, with a SwiftPM-first build path targeting Apple Silicon Macs.

## Documentation

- [docs/CODE_ARCHITECTURE.md](docs/CODE_ARCHITECTURE.md): high-level system design, major components, and data flow.
- [docs/FILE_STRUCTURE.md](docs/FILE_STRUCTURE.md): directory map with what belongs where, including generated assets.
- [docs/INSTALL.md](docs/INSTALL.md): setup steps, dependencies, and environment requirements.
- [docs/USAGE.md](docs/USAGE.md): how to run the app and its scripts, with practical examples.
- [docs/SCOPE.md](docs/SCOPE.md): what this fork keeps, cuts, and defers relative to upstream CodeEdit.
- [docs/DEVELOPER_USAGE.md](docs/DEVELOPER_USAGE.md): full build, packaging, and smoke-test reference.

More reference docs (style guides, the Kate syntax pipeline, theming, related projects) live under `docs/`; see `AGENTS.md` for the full agent-facing index.

## Quick start

1. Run `./build_debug.sh` to build and launch the debug app with SwiftPM.
2. Run `./build_release.sh` to make a release build, with optional install to `/Applications` via `INSTALL_TO_APPLICATIONS=1`.
3. Run `bash scripts/make_app_bundle.sh` to package a `.app` bundle; see [docs/DEVELOPER_USAGE.md](docs/DEVELOPER_USAGE.md) for the full build reference.

## Screenshots

<!-- screenshots:begin (managed by screenshot-docs) -->
![Plain editor window with toolbar and bottom status bar](docs/screenshots/codeedit_window.png)
<!-- screenshots:end -->
