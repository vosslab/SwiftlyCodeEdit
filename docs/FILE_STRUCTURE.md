# File structure

## Top-level layout

- [`CodeEdit/`](../CodeEdit/): active app source. This is the main product code area and still contains legacy subtrees during the cutover.
- [`Packages/`](../Packages/): local Swift packages used by the app and editor.
- [`CodeEditTests/`](../CodeEditTests/): unit and feature tests.
- [`CodeEditUITests/`](../CodeEditUITests/): UI tests.
- [`docs/`](.): repo guidance, architecture notes, changelog, and supporting documentation.
- [`devel/`](../devel/): scripts and maintenance tooling.
- [`Resources/`](../Resources/): shared app resources.
- [`DefaultThemes/`](../DefaultThemes/): theme data files.
- [`Documentation.docc/`](../Documentation.docc/): developer documentation content.
- [`AppCast/`](../AppCast/): release feed assets.
- [`OpenWithCodeEdit/`](../OpenWithCodeEdit/): helper app target for file-opening integration.
- [`CodeEdit.xcodeproj/`](../CodeEdit.xcodeproj/): Xcode project for IDE workflows.

## Key subtrees

- [`CodeEdit/Features/Editor/`](../CodeEdit/Features/Editor/): plain editor views, document bridge, status reporting, Clean Text, and editor state.
- [`CodeEdit/Features/Documents/`](../CodeEdit/Features/Documents/): document model and window/document coordination.
- `CodeEdit/Features/SmokeTesting/`: narrow App Intents smoke hooks for deterministic validation.
- [`Packages/CodeEditTextView/`](../Packages/CodeEditTextView/): text view implementation package.
- [`Packages/CodeEditLanguages/`](../Packages/CodeEditLanguages/): language metadata package.
- [`Packages/CodeEditSyntaxDefinitions/`](../Packages/CodeEditSyntaxDefinitions/): syntax definition data package.
- [`Packages/CodeEditHighlighting/`](../Packages/CodeEditHighlighting/): shared highlighting model and Kate XML interpreter.
- [`CodeEdit/Features/LSP/`](../CodeEdit/Features/LSP/): legacy IDE surface, still present but outside the plain-editor build path.
- [`CodeEdit/Features/NavigatorArea/`](../CodeEdit/Features/NavigatorArea/): legacy navigator shell, still being simplified.
- [`CodeEdit/Features/InspectorArea/`](../CodeEdit/Features/InspectorArea/): legacy inspector shell, still being simplified.
- [`CodeEdit/Features/SourceControl/`](../CodeEdit/Features/SourceControl/): IDE-era source control support, outside this milestone.
- `test-results/plain_editor_smoke/`: generated smoke logs for the live plain-editor validation path.

## Generated artifacts

- SwiftPM build output lives under `.build/` and is generated.
- Temporary scratch data may appear under `.tmp/` and is generated.
- Xcode-derived data is not part of the source layout and should stay out of the repo tree.

## Documentation map

- [`REPO_STYLE.md`](REPO_STYLE.md): repo rules and workflow.
- [`SWIFT_STYLE.md`](SWIFT_STYLE.md): Swift and SwiftUI guidance.
- [`LIQUID_GLASS.md`](LIQUID_GLASS.md): macOS 26 UI guidance.
- [`CODE_ARCHITECTURE.md`](CODE_ARCHITECTURE.md): intended post-cutover architecture.
- [`FILE_STRUCTURE.md`](FILE_STRUCTURE.md): this folder map.
- [`CHANGELOG.md`](CHANGELOG.md): change history.

## Where to add new work

- Editor features: `CodeEdit/Features/Editor/`.
- Document behavior: `CodeEdit/Features/Documents/`.
- Smoke-test hooks: `CodeEdit/Features/SmokeTesting/`.
- Shared packages: `Packages/`.
- Tests: `CodeEditTests/` and `CodeEditUITests/`.
- Docs and repo notes: `docs/`.
- Build or maintenance scripts: `devel/` or the repo root for small wrappers.

## Plain-editor cutover

These areas are still being simplified and should be treated as transitional:

- `CodeEdit/Features/LSP/`
- `CodeEdit/Features/NavigatorArea/`
- `CodeEdit/Features/InspectorArea/`
- `CodeEdit/Features/SourceControl/`
- `CodeEdit/Features/ActivityViewer/`
- `CodeEdit/Features/Notifications/`
- `CodeEdit/Features/Tasks/`
- `CodeEdit/Features/CEWorkspace/`

The active SwiftPM target excludes those transitional directories from the
required build path while the app is being narrowed to SwiftlyCodeEdit's plain
editor surface.
