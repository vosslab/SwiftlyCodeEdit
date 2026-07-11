//
//  EditorCommandRouter.swift
//  SwiftlyCodeEdit
//
//  The single shared action router for editor commands. Both the SwiftUI
//  `Commands` menu (EditorCommands.swift) and the in-window native toolbar
//  (CodeFileView.swift) call these functions, so a menu item and its toolbar button
//  always run the same code path. Undo and redo resolve through the target
//  `TextView`'s own `undoManager`, keeping a single undo owner per the architect
//  decision; nothing here touches `\.environment(\.undoManager)`.
//
//  Multi-window targeting model: each editor window
//  registers its `TextView` under a stable per-window key, and the document bridge
//  reports which window is key. Menu commands resolve to the key window's editor;
//  toolbar buttons pass their own window's editor directly. This replaces the old
//  single last-write-wins weak slot, which silently misdirected menu commands to the
//  last-opened window and no-oped once that window closed.
//
//  State model per Resolved decisions (docs/SWIFT_STYLE.md sections 4 and 5): this
//  is an `Observable`, main-actor-isolated type, replacing the retired
//  `ObservableObject` PlainEditorActionRouter that lived in the old AppKit shell.
//  The AppKit boundary stays clean: window key/close observation lives in the
//  sanctioned document bridge, so this router imports no AppKit shell symbols.
//

import Foundation
import Observation
import CodeEditTextView

/// Routes editor actions to the correct `TextView`. Each window registers its editor
/// under a per-window key; the menu resolves to the key window's editor while the
/// toolbar passes its own. Both invoke the same underlying action functions.
@Observable
@MainActor
final class EditorCommandRouter {
    /// The one router every command surface talks to. Main-actor isolated because
    /// it drives editor `TextView`s, which are UI state.
    static let shared = EditorCommandRouter()

    // A weak box so a closed window's editor never keeps the registry alive; a
    // dropped entry is pruned lazily on the next lookup.
    private struct WeakEditor {
        weak var textView: TextView?
    }

    // A weak box for a window's find panel model, so a closed window's panel is not
    // kept alive by the registry.
    private struct WeakFindModel {
        weak var model: FindPanelModel?
    }

    // One entry per editor window, keyed by the hosting document's identity. The
    // SwiftUI view registers its `TextView` here as it becomes ready; the document
    // bridge keys the same identity when it observes that window becoming key or
    // closing. Routing state, not observable model data, so it is excluded from
    // observation tracking.
    @ObservationIgnored private var editors: [ObjectIdentifier: WeakEditor] = [:]

    // One find panel model per editor window, keyed the same way as `editors`. The
    // editor view registers its model as its text view becomes ready; a Find menu
    // command resolves to the key window's model and presents it.
    @ObservationIgnored private var findModels: [ObjectIdentifier: WeakFindModel] = [:]

    // Identity of the window AppKit last reported as key. Menu commands resolve
    // through this so they always target the focused window's editor.
    @ObservationIgnored private var activeWindowKey: ObjectIdentifier?

    // Tab width used by the Clean Text tab/space conversions.
    // Hardcoded for now; the Settings scene will own this as a persisted
    // preference. Wiring this to the real setting is a named follow-up.
    private let cleanTabWidth = 4

    // MARK: - Registration lifecycle

    /// Records the editor for a window so menu commands can later target it. Called
    /// from the view when its `TextView` becomes ready. `windowKey` is the hosting
    /// document's `ObjectIdentifier`, the same identity the bridge keys on.
    func register(textView: TextView, for windowKey: ObjectIdentifier) {
        editors[windowKey] = WeakEditor(textView: textView)
    }

    /// Records the find panel model for a window so a Find menu command can present it.
    /// Called from the editor view once its text view is ready, keyed on the same
    /// document identity the text view is registered under.
    func register(findModel: FindPanelModel, for windowKey: ObjectIdentifier) {
        findModels[windowKey] = WeakFindModel(model: findModel)
    }

    /// Drops a window's editor when that window closes, so routing never dangles on
    /// a stale entry. Clears the active key when the closing window was the key one.
    func unregister(for windowKey: ObjectIdentifier) {
        editors[windowKey] = nil
        findModels[windowKey] = nil
        if activeWindowKey == windowKey {
            activeWindowKey = nil
        }
    }

    /// Records which window is key, so subsequent menu commands route to its editor.
    /// Called from the bridge on each key-window change.
    func setActiveWindow(_ windowKey: ObjectIdentifier) {
        activeWindowKey = windowKey
    }

    /// The window a menu command targets: the sole registered window when only one is
    /// open, else the key window. Single-window has no ambiguity, so this stays correct
    /// even before any key-window notification has arrived (the launch and self-test
    /// path). Returns nil when no editor is live. Both the editor and the find-model
    /// lookups resolve through this one helper, so they always agree on which window.
    private var resolvedWindowKey: ObjectIdentifier? {
        pruneDeadEditors()
        if editors.count == 1 {
            return editors.keys.first
        }
        return activeWindowKey
    }

    /// The editor a menu command targets: the resolved window's editor, or nil when no
    /// editor is live.
    private var activeEditor: TextView? {
        guard let windowKey = resolvedWindowKey else { return nil }
        return editors[windowKey]?.textView
    }

    /// The find panel model a Find menu command presents: the resolved window's model,
    /// or nil when none is registered.
    private var activeFindModel: FindPanelModel? {
        guard let windowKey = resolvedWindowKey else { return nil }
        return findModels[windowKey]?.model
    }

    /// Removes entries whose editor has been deallocated (a window closed without a
    /// matching unregister), clearing the active key if it pointed at one.
    private func pruneDeadEditors() {
        for (key, box) in editors where box.textView == nil {
            editors[key] = nil
            if activeWindowKey == key {
                activeWindowKey = nil
            }
        }
    }

    // MARK: - Menu commands (resolve the key window's editor)

    /// Undoes the last edit in the key window's editor. Returns false when no editor
    /// is active or there is nothing to undo.
    func undo() -> Bool {
        guard let activeEditor else { return false }
        return undo(on: activeEditor)
    }

    /// Redoes the last undone edit in the key window's editor.
    func redo() -> Bool {
        guard let activeEditor else { return false }
        return redo(on: activeEditor)
    }

    /// Cuts the selection in the key window's editor.
    func cut() -> Bool {
        guard let activeEditor else { return false }
        return cut(on: activeEditor)
    }

    /// Copies the selection in the key window's editor.
    func copy() -> Bool {
        guard let activeEditor else { return false }
        return copy(on: activeEditor)
    }

    /// Pastes the system pasteboard string into the key window's editor.
    func paste() -> Bool {
        guard let activeEditor else { return false }
        return paste(on: activeEditor)
    }

    /// Selects all text in the key window's editor.
    func selectAll() -> Bool {
        guard let activeEditor else { return false }
        return selectAll(on: activeEditor)
    }

    /// Trims trailing horizontal whitespace across the key window's editor.
    func cleanText() -> Bool {
        guard let activeEditor else { return false }
        return cleanText(on: activeEditor)
    }

    /// Rewrites every line ending in the key window's editor to LF.
    func cleanLineEndingsToLF() -> Bool {
        guard let activeEditor else { return false }
        return cleanLineEndingsToLF(on: activeEditor)
    }

    /// Rewrites every line ending in the key window's editor to CRLF.
    func cleanLineEndingsToCRLF() -> Bool {
        guard let activeEditor else { return false }
        return cleanLineEndingsToCRLF(on: activeEditor)
    }

    /// Appends a trailing newline to the key window's editor if missing.
    func cleanFinalNewline() -> Bool {
        guard let activeEditor else { return false }
        return cleanFinalNewline(on: activeEditor)
    }

    /// Expands leading tabs to spaces across the key window's editor.
    func cleanTabsToSpaces() -> Bool {
        guard let activeEditor else { return false }
        return cleanTabsToSpaces(on: activeEditor)
    }

    /// Collapses leading indentation spaces to tabs across the key window's editor.
    func cleanSpacesToTabs() -> Bool {
        guard let activeEditor else { return false }
        return cleanSpacesToTabs(on: activeEditor)
    }

    /// Converts smart punctuation to ASCII across the key window's editor. An
    /// explicit opt-in action; never applied silently by any other Clean Text action.
    func cleanSmartPunctuationToASCII() -> Bool {
        guard let activeEditor else { return false }
        return cleanSmartPunctuationToASCII(on: activeEditor)
    }

    // MARK: - Target commands (act on a caller-supplied editor)
    //
    // The toolbar passes its own window's editor here so its buttons always target
    // the window they live in, staying consistent with that window's enabled-state
    // bindings. The menu forms above resolve the key window and then call these, so
    // toolbar and menu invoke the same action functions.

    /// Undoes the last edit through the given editor's own undo manager, the single
    /// undo owner. Returns false when there is nothing to undo.
    func undo(on textView: TextView) -> Bool {
        guard let undoManager = textView.undoManager, undoManager.canUndo else { return false }
        undoManager.undo()
        return true
    }

    /// Redoes the last undone edit through the given editor's undo manager.
    func redo(on textView: TextView) -> Bool {
        guard let undoManager = textView.undoManager, undoManager.canRedo else { return false }
        undoManager.redo()
        return true
    }

    /// Cuts the current selection through the given editor.
    func cut(on textView: TextView) -> Bool {
        textView.cut(textView)
        return true
    }

    /// Copies the current selection through the given editor. `TextView.copy`
    /// already handles multi-cursor selections and no-ops on an empty selection.
    func copy(on textView: TextView) -> Bool {
        textView.copy(textView)
        return true
    }

    /// Pastes the live system pasteboard string through the given editor.
    /// `TextView.paste` reads the live pasteboard and no-ops when it holds no string.
    func paste(on textView: TextView) -> Bool {
        textView.paste(textView)
        return true
    }

    /// Selects all text in the given editor.
    func selectAll(on textView: TextView) -> Bool {
        textView.selectAll(nil)
        return true
    }

    /// Trims trailing horizontal whitespace across the given editor's text. The
    /// replacement is a single edit so it undoes as one operation. Returns false when
    /// the editor is read-only or there is nothing to trim.
    func cleanText(on textView: TextView) -> Bool {
        applyCleanTransform(on: textView) { PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: $0) }
    }

    /// Rewrites every line ending in the given editor's text to LF, as a single
    /// undoable edit.
    func cleanLineEndingsToLF(on textView: TextView) -> Bool {
        applyCleanTransform(on: textView) { PlainEditorTextCleaner.normalizeLineEndings(in: $0, to: .lf) }
    }

    /// Rewrites every line ending in the given editor's text to CRLF, as a single
    /// undoable edit.
    func cleanLineEndingsToCRLF(on textView: TextView) -> Bool {
        applyCleanTransform(on: textView) { PlainEditorTextCleaner.normalizeLineEndings(in: $0, to: .crlf) }
    }

    /// Appends a trailing LF to the given editor's text if missing, as a single
    /// undoable edit.
    func cleanFinalNewline(on textView: TextView) -> Bool {
        applyCleanTransform(on: textView) { PlainEditorTextCleaner.ensureFinalNewline(in: $0, using: .lf) }
    }

    /// Expands leading tabs to spaces across the given editor's text at the
    /// hardcoded Clean Text tab width, as a single undoable edit.
    func cleanTabsToSpaces(on textView: TextView) -> Bool {
        applyCleanTransform(on: textView) {
            PlainEditorTextCleaner.convertTabsToSpaces(in: $0, tabWidth: cleanTabWidth)
        }
    }

    /// Collapses leading indentation spaces to tabs across the given editor's text
    /// at the hardcoded Clean Text tab width, as a single undoable edit.
    func cleanSpacesToTabs(on textView: TextView) -> Bool {
        applyCleanTransform(on: textView) {
            PlainEditorTextCleaner.convertSpacesToTabs(in: $0, tabWidth: cleanTabWidth)
        }
    }

    /// Converts smart punctuation to ASCII across the given editor's text, as a
    /// single undoable edit. An explicit opt-in action; never applied silently by
    /// any other Clean Text action.
    func cleanSmartPunctuationToASCII(on textView: TextView) -> Bool {
        applyCleanTransform(on: textView) { PlainEditorTextCleaner.normalizeSmartPunctuationToASCII(in: $0) }
    }

    /// Shared single-edit apply path for every Clean Text action: replaces the
    /// whole document in one `replaceCharacters` call (one undoable operation) and
    /// no-ops when the editor is read-only or the transform made no change.
    private func applyCleanTransform(on textView: TextView, transform: (String) -> String) -> Bool {
        guard textView.isEditable else { return false }
        let original = textView.string
        let cleaned = transform(original)
        guard cleaned != original else { return false }
        textView.replaceCharacters(
            in: NSRange(location: 0, length: (original as NSString).length),
            with: cleaned
        )
        return true
    }

    // MARK: - Find

    /// Opens the find bar over the key window's editor in find mode (Cmd-F). The
    /// FIND_REQUESTED marker fires first so the menu wiring stays provable; presenting
    /// no-ops harmlessly when no window has registered a find model yet.
    func requestFind() {
        debugRuntimeLog("FIND_REQUESTED mode=find")
        activeFindModel?.present(mode: .find)
    }

    /// Opens the find bar over the key window's editor with replace revealed
    /// (Cmd-Opt-F); see `requestFind()`.
    func requestFindAndReplace() {
        debugRuntimeLog("FIND_REQUESTED mode=replace")
        activeFindModel?.present(mode: .replace)
    }
}
