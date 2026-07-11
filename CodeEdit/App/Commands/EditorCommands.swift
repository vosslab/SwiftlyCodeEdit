//
//  EditorCommands.swift
//  SwiftlyCodeEdit
//
//  The SwiftUI `Commands` menu for the editor, attached to the app scene in
//  SwiftlyCodeEditApp.swift. It declares the File, Edit, Find, and Format menus that
//  replace the hand-built PlainEditorMainMenu, preserving every keyboard shortcut
//  from the menu-shortcut inventory. Document commands route through the sanctioned
//  document bridge (`ShellDocumentActions`); editor commands route through the shared
//  `EditorCommandRouter`, the same functions the native toolbar calls.
//

import SwiftUI

struct EditorCommands: Commands {
    // Backs the Format menu's Increase/Decrease/Reset Size items.
    // This is the same `PlainEditor.fontFamily` / `PlainEditor.fontSize`
    // @AppStorage key pair the Settings scene reads and writes, so a
    // menu invocation and a Settings-pane edit stay in sync across
    // every open window with no extra routing needed.
    @AppStorage("PlainEditor.fontFamily")
    private var editorFontFamily = PlainEditorFontSettings.defaultFontFamily
    @AppStorage("PlainEditor.fontSize")
    private var editorFontSize = PlainEditorFontSettings.defaultFontSize

    var body: some Commands {
        // MARK: File
        // New (Cmd+N) and Open (Cmd+O) replace the standard new-document group.
        CommandGroup(replacing: .newItem) {
            Button("New") {
                ShellDocumentActions.newDocument()
            }
            .keyboardShortcut("n")

            Button("Open...") {
                ShellDocumentActions.openDocumentWithPanel()
            }
            .keyboardShortcut("o")
        }
        // Save (Cmd+S), Save As (Cmd+Shift+S), and Close (Cmd+W) replace the standard
        // save group, matching the inventory's explicit key-window Close.
        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                ShellDocumentActions.saveActiveDocument()
            }
            .keyboardShortcut("s")

            Button("Save As...") {
                ShellDocumentActions.saveActiveDocumentAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Close") {
                ShellDocumentActions.closeActiveDocument()
            }
            .keyboardShortcut("w")
        }

        // MARK: Edit
        // Undo (Cmd+Z) and Redo (Cmd+Shift+Z) resolve through the active editor's
        // undo manager via the shared router.
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                _ = EditorCommandRouter.shared.undo()
            }
            .keyboardShortcut("z")

            Button("Redo") {
                _ = EditorCommandRouter.shared.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        // Cut, Copy, Paste, Select All, then Clean Text (no shortcut), matching the
        // old Edit menu order. Replacing the standard pasteboard group avoids a
        // duplicate Select All from SwiftUI's defaults.
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                _ = EditorCommandRouter.shared.cut()
            }
            .keyboardShortcut("x")

            Button("Copy") {
                _ = EditorCommandRouter.shared.copy()
            }
            .keyboardShortcut("c")

            Button("Paste") {
                _ = EditorCommandRouter.shared.paste()
            }
            .keyboardShortcut("v")

            Button("Select All") {
                _ = EditorCommandRouter.shared.selectAll()
            }
            .keyboardShortcut("a")

            Divider()

            // Clean Text submenu: each item is a single
            // undoable whole-document transform, applied through the shared
            // router so a menu invocation and the toolbar's Clean Text button
            // run the same code path. No keyboard shortcuts here; the
            // menu-shortcut parity inventory has none for Clean Text.
            Menu("Clean Text") {
                Button("Trim Trailing Whitespace") {
                    _ = EditorCommandRouter.shared.cleanText()
                }

                Divider()

                Button("Normalize Line Endings to LF") {
                    _ = EditorCommandRouter.shared.cleanLineEndingsToLF()
                }

                Button("Normalize Line Endings to CRLF") {
                    _ = EditorCommandRouter.shared.cleanLineEndingsToCRLF()
                }

                Button("Ensure Final Newline") {
                    _ = EditorCommandRouter.shared.cleanFinalNewline()
                }

                Divider()

                Button("Convert Tabs to Spaces") {
                    _ = EditorCommandRouter.shared.cleanTabsToSpaces()
                }

                Button("Convert Spaces to Tabs") {
                    _ = EditorCommandRouter.shared.cleanSpacesToTabs()
                }

                Divider()

                // Explicit opt-in: the label names the ASCII conversion outright
                // so it is never mistaken for a silent, always-on cleanup step.
                Button("Convert Smart Punctuation to ASCII") {
                    _ = EditorCommandRouter.shared.cleanSmartPunctuationToASCII()
                }
            }
        }
        // The editor is a custom NSView, not a SwiftUI text control, so SwiftUI's
        // default Find/Spelling/Substitutions section would only bind dead shortcuts.
        // Emptying it keeps Cmd+F single-bound to the top-level Find menu below.
        CommandGroup(replacing: .textEditing) { }

        // MARK: Find
        // A top-level Find menu, matching the old menu bar. Find (Cmd+F) and Find and
        // Replace (Cmd+Opt+F) present the find panel via EditorCommandRouter.requestFind()
        // and requestFindAndReplace().
        CommandMenu("Find") {
            Button("Find...") {
                EditorCommandRouter.shared.requestFind()
            }
            .keyboardShortcut("f")

            Button("Find and Replace...") {
                EditorCommandRouter.shared.requestFindAndReplace()
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
        }

        // MARK: Format
        // Font family lives in the Settings scene's General pane; size
        // adjustment lives here so it is reachable without opening
        // Settings, matching Zoom In/Out/Reset conventions elsewhere on
        // macOS. Both items call the same `PlainEditorFontSettings.increasedFontSize`/
        // `decreasedFontSize` step functions, which clamp the size to the allowed range.
        CommandMenu("Format") {
            Button("Font and Text Options") { }
                .disabled(true)

            Divider()

            Button("Increase Size") {
                editorFontSize = PlainEditorFontSettings.increasedFontSize(from: editorFontSize)
            }
            .keyboardShortcut("+", modifiers: [.command])
            .disabled(editorFontSize >= PlainEditorFontSettings.maximumFontSize)

            Button("Decrease Size") {
                editorFontSize = PlainEditorFontSettings.decreasedFontSize(from: editorFontSize)
            }
            .keyboardShortcut("-", modifiers: [.command])
            .disabled(editorFontSize <= PlainEditorFontSettings.minimumFontSize)

            Button("Reset Size") {
                editorFontFamily = PlainEditorFontSettings.defaultFontFamily
                editorFontSize = PlainEditorFontSettings.defaultFontSize
            }
            .keyboardShortcut("0", modifiers: [.command])
        }
    }
}
