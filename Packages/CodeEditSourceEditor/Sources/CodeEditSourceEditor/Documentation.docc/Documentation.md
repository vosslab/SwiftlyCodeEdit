# ``CodeEditSourceEditor``

A code editor with source editing, syntax highlighting hooks, and editor behaviors for CodeEdit.

## Overview

CodeEditSourceEditor logo

An Xcode-inspired code editor view written in Swift for [CodeEdit](https://github.com/CodeEditApp/CodeEdit). Features include syntax highlighting hooks, code completion, find and replace, text diff, validation, current line highlighting, minimap, inline messages (warnings and errors), bracket matching, and more.

Preview banner

This package includes both `AppKit` and `SwiftUI` components. Syntax highlighting is supplied through editor-facing highlight providers.

> **CodeEditSourceEditor is currently in development and it is not ready for production use.** <br> Please check back later for updates on this project. Contributors are welcome as we build out the features mentioned above!

## Currently Supported Languages

See this issue [CodeEditLanguages#10](https://github.com/CodeEditApp/CodeEditLanguages/issues/10) on `CodeEditLanguages` for more information on supported languages.

## Dependencies

Special thanks to everyone contributing editor tooling and syntax definition work in the Swift and editor ecosystem.

## License

Licensed under the [MIT license](https://github.com/CodeEditApp/CodeEdit/blob/main/LICENSE.md).

## Topics

### Text View

- <doc:SourceEditorView>
- ``SourceEditor``
- ``SourceEditorConfiguration``
- ``SourceEditorState``
- ``TextViewController``
- ``GutterView``

### Themes

- ``EditorTheme``

### Text Coordinators

- <doc:TextViewCoordinators>
- ``TextViewCoordinator``
- ``CombineCoordinator``

### Cursors

- ``CursorPosition``
