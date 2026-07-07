# Code architecture

## Overview

This repo is being cut over to a lightweight macOS text editor, not a full IDE. The required path is the plain editor shell, syntax highlighting, find/replace, autosave, external file-change detection, and data-driven themes and syntax definitions.

SwiftUI owns the app shell. AppKit and TextKit own the editor surface through a narrow bridge in `PlainTextEditorView` and `CodeEditTextView`.

## Major components

- [`CodeEdit/CodeEditApp.swift`](../CodeEdit/CodeEditApp.swift): app entry point and scene setup.
- [`CodeEdit/WorkspaceView.swift`](../CodeEdit/WorkspaceView.swift): main workspace shell for the plain editor path.
- [`CodeEdit/Features/Editor/Views/CodeFileView.swift`](../CodeEdit/Features/Editor/Views/CodeFileView.swift): document-to-editor bridge used by the plain editor surface.
- [`CodeEdit/Features/Editor/Views/PlainTextEditorView.swift`](../CodeEdit/Features/Editor/Views/PlainTextEditorView.swift): AppKit/TextKit wrapper around `CodeEditTextView.TextView`.
- [`CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift`](../CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift): document model for open, edit, autosave, and external-change handling.
- [`Packages/CodeEditTextView/`](../Packages/CodeEditTextView/): local text-view package that provides the editable text surface.
- [`Packages/CodeEditLanguages/`](../Packages/CodeEditLanguages/): language metadata used for syntax selection.
- [`Packages/CodeEditSyntaxDefinitions/`](../Packages/CodeEditSyntaxDefinitions/): syntax definition data files.
- [`DefaultThemes/`](../DefaultThemes/): theme data files.

## Required build path

The plain-editor build should compile the app shell, editor view chain, settings, welcome/about surfaces, and shared UI helpers needed by the editor.

Required path:

- App shell and scene setup.
- Workspace and window shell for the editor.
- Plain editor view bridge.
- Document model, autosave, and external file-change reload.
- Find/replace and syntax/theme loading.
- Data bundles for themes and syntax definitions.

## Outside this milestone

These surfaces remain legacy or optional during the cutover:

- Source control.
- LSP and semantic-token plumbing.
- Navigator UI.
- Inspector UI.
- Activity/task/notification chrome tied to the old IDE shell.
- Terminal and utility panes not required for the plain editor path.
- Old `SourceEditor`-style editor surfaces that duplicate the plain text editor path.

## Ownership split

- SwiftUI owns app structure, windows, commands, and standard controls.
- AppKit owns the text view bridge and other narrow platform behaviors.
- TextKit owns the actual editor editing mechanics through `CodeEditTextView`.
- Data files own syntax definitions and themes so new content can be added without rebuilding app logic.

## Known gaps

- The target still contains legacy folders that are being removed from the required build path.
- Some old feature trees remain in the repo for reference while the plain-editor cutover finishes.
