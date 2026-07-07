# Plain Editor Smoke Test

Use this against a local debug build.

## Build

```bash
./build_debug.sh
```

## Launch

```bash
./.build/debug/CodeEdit
```

## File

Open `CodeEdit/CodeEditApp.swift` on debug launch. The window title should show `CodeEditApp.swift`.

## Expected

- Source text is visible in the editor.
- The insertion point appears in the text view.
- Typing updates the document.
- Save writes the edited text to disk.
- Open, Save, Close, Undo, Redo, Cut, Copy, Paste, Select All, and Find are present in the app menus.

