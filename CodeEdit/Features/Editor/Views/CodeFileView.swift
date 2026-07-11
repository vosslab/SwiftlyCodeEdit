//
//  CodeFileView.swift
//  CodeEditModules/CodeFile
//
//  Created by Marco Carnevali on 17/03/22.
//

import Foundation
import SwiftUI
import CodeEditTextView
import CodeEditLanguages
import CodeEditHighlighting
import CodeEditSyntaxDefinitions

/// CodeFileView is just a wrapper of the `CodeEditor` dependency
struct CodeFileView: View {
    @ObservedObject private var codeFile: CodeFileDocument
    @StateObject private var chrome = PlainEditorChromeModel()
    @State private var activeTextView: TextView?
    // Guards a single registration of the reload observer that refreshes the
    // status bar (encoding label included) after a silent external reload, which
    // replaces the buffer via the document's storage swap rather than a keystroke.
    @State private var didObserveReloads = false
    // Guards a single registration of the bounded-rehighlight observer,
    // which drives per-keystroke syntax coloring from the document's edited-range
    // broadcast so exactly one bounded pass runs per edit.
    @State private var didObserveHighlightEdits = false
    // This window's find/replace bar. Presented by the shared router when a
    // Find menu command resolves to this window; bound to this window's editor as the
    // text view becomes ready.
    @State private var findModel = FindPanelModel()
    @AppStorage("PlainEditor.fontFamily")
    private var editorFontFamily = PlainEditorFontSettings.defaultFontFamily
    @AppStorage("PlainEditor.fontSize")
    private var editorFontSize = PlainEditorFontSettings.defaultFontSize
    // Observes the Settings scene's theme picker. Every open
    // document window's CodeFileView holds this same @AppStorage key, so a
    // theme change in Settings re-renders every window and the onChange
    // below re-triggers a highlight pass with no relaunch required.
    @AppStorage(PlainEditorSettingsKeys.themeName)
    private var editorThemeName = ThemeRepository.bundledDefaultThemeName

    private let isEditable: Bool
    private let wrapLinesToEditorWidth = true
    private let useSystemCursor = true
    private var editorFont: NSFont {
        PlainEditorFontSettings.font(family: editorFontFamily, size: editorFontSize)
    }

    init(codeFile: CodeFileDocument, isEditable: Bool = true) {
        self._codeFile = .init(wrappedValue: codeFile)
        self.isEditable = isEditable
    }

    var body: some View {
        VStack(spacing: 0) {
            if findModel.isPresented {
                FindPanelView(model: findModel)
            }

            ZStack(alignment: .topLeading) {
                PlainTextEditorView(
                    textStorage: Binding(
                        get: { codeFile.content ?? NSTextStorage() },
                        set: { codeFile.content = $0 }
                    ),
                    isEditable: isEditable,
                    isSelectable: true,
                    wrapLines: wrapLinesToEditorWidth,
                    useSystemCursor: useSystemCursor,
                    font: editorFont,
                    textColor: .textColor,
                    lineHeightMultiplier: 1,
                    edgeInsets: .init(left: 12, right: 12),
                    textInsets: .init(left: 0, right: 0),
                    onTextChange: {
                        // Syntax coloring is driven by the document's edited-range
                        // broadcast (the bounded-rehighlight observer registered in
                        // onTextViewReady), not from here, so exactly one bounded
                        // pass runs per edit instead of a whole-document pass on top
                        // of the edited-range signal (bounded double-highlight dedup).
                        chrome.refreshForEdit(document: codeFile, selection: activeTextView?.selectedRange())
                        // Tell the find bar the document changed so it can re-scan and
                        // never act on a match range that the edit left out of bounds
                        // (stale-match crash). The model ignores its own Replace
                        // edits via an internal flag.
                        findModel.handleExternalTextChange()
                    },
                    onEdit: { replacedRange, newLength in
                        // The document owns change tracking (document state contract):
                        // report each mutation with how it reached the buffer so undo
                        // back to the saved text clears the dirty flag and redo away
                        // sets it again. Undo/redo replay one mutation per replaced
                        // range, so this per-range callback stays balanced with the
                        // forward edits that dirtied the document.
                        let editKind: CodeFileDocument.EditKind
                        if activeTextView?.undoManager?.isUndoing == true {
                            editKind = .undo
                        } else if activeTextView?.undoManager?.isRedoing == true {
                            editKind = .redo
                        } else {
                            editKind = .edit
                        }
                        codeFile.recordEdit(editKind, replacedRange: replacedRange, newLength: newLength)
                    },
                    onSelectionChange: { selection in
                        chrome.refreshForSelectionChange(document: codeFile, selection: selection)
                    },
                    onTextStorageReady: { storage in
                        // Fire the initial full highlight only while the text view
                        // is not yet ready (the makeNSViewController pass). This
                        // closure is also called from every updateNSViewController,
                        // which SwiftUI re-runs on each keystroke (chrome.refresh
                        // mutates @Published state); without this guard every edit
                        // would schedule a whole-document highlight on top of the
                        // bounded rehighlight, defeating it. After the view is
                        // ready, edits are highlighted by the bounded edited-range
                        // observer below, and reloads by the document's read path.
                        guard activeTextView == nil else { return }
                        PlainSyntaxHighlighter.highlight(storage: storage, language: codeFile.getLanguage())
                    },
                    onTextViewReady: { textView in
                        activeTextView = textView
                        // Key the registration on this window's document identity so
                        // the router can target this specific editor; the document
                        // bridge keys the same identity for key-window tracking.
                        EditorCommandRouter.shared.register(
                            textView: textView,
                            for: ObjectIdentifier(codeFile)
                        )
                        // Bind this window's find bar to its editor and register it so
                        // a Find menu command can present it, keyed on the same
                        // document identity as the text view above.
                        findModel.bind(target: TextViewFindTarget(textView: textView))
                        EditorCommandRouter.shared.register(
                            findModel: findModel,
                            for: ObjectIdentifier(codeFile)
                        )
                        PlainSyntaxHighlighter.highlight(textView: textView, language: codeFile.getLanguage())
                        chrome.refresh(document: codeFile, selection: textView.selectedRange())
                        // A silent external reload (clean + valid) swaps the shared
                        // storage in place and broadcasts .fullInvalidation without a
                        // keystroke. This window owns the text view and its undo manager,
                        // so it responds to that document event here: reset the undo stack
                        // and refresh the status bar. The document stays out of the undo
                        // seam -- it only announces that the whole buffer changed; the
                        // editor layer that holds the undo manager decides the history is
                        // meaningless and clears it. Weak captures keep the document-held
                        // closure from retaining this window's document, chrome, or view
                        // past close.
                        if !didObserveReloads {
                            didObserveReloads = true
                            codeFile.addEditObserver { [weak codeFile, weak chrome, weak textView] change in
                                guard case .fullInvalidation = change else { return }
                                // The in-place storage swap bypassed setTextStorage's own
                                // clearStack, so the undo stack still references pre-reload
                                // offsets. Reset it so a post-reload Undo is a clean no-op,
                                // never a corrupting replay against mismatched content (F4).
                                textView?._undoManager?.clearStack()
                                // Pick up the reloaded encoding label; nothing else triggers
                                // a chrome refresh on a keystroke-less reload (F7).
                                guard let codeFile, let chrome else { return }
                                chrome.refresh(document: codeFile, selection: nil)
                            }
                        }
                        // Bounded rehighlight: a range edit (typing, paste,
                        // undo, redo, find-replace, Clean Text) reinterprets only a
                        // region around the edit and paints just that region. A
                        // full invalidation comes only from an external reload, which
                        // reinterprets the whole buffer from the document's read path
                        // already, so it needs no rehighlight here.
                        if !didObserveHighlightEdits {
                            didObserveHighlightEdits = true
                            codeFile.addEditObserver { [weak codeFile, weak textView] change in
                                guard case let .range(replacedRange, newLength) = change,
                                      let codeFile, let textView else { return }
                                #if DEBUG
                                debugRuntimeLog("REHIGHLIGHT_OBSERVER range=\(replacedRange) newLength=\(newLength)")
                                #endif
                                PlainSyntaxHighlighter.rehighlight(
                                    textView: textView,
                                    language: codeFile.getLanguage(),
                                    editedRange: replacedRange,
                                    newLength: newLength
                                )
                            }
                        }
                        #if DEBUG
                        PlainEditorCommandSelfTest.scheduleIfRequested(textView: textView)
                        PlainEditorConflictScenarioSelfTest.scheduleIfRequested(textView: textView)
                        PlainEditorKeystrokeBench.scheduleIfRequested(textView: textView)
                        PlainEditorSettingsApplySelfTest.scheduleIfRequested()
                        WindowCaptureScheduler.scheduleIfRequested(textView: textView)
                        #endif
                    }
                )
                // This view needs to refresh when the codefile changes. The file URL is too stable.
                .id(ObjectIdentifier(codeFile))
                .background(Color(nsColor: .textBackgroundColor))
                // minHeight zero fixes a bug where the app would freeze if the contents of the file are empty.
                .frame(minHeight: .zero, maxHeight: .infinity)

                if codeFile.content?.length == 0 {
                    Text("Open a source file to begin editing")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }

            PlainEditorStatusBar(chrome: chrome)
        }
        .toolbar {
            editorToolbar()
        }
        .onAppear {
            chrome.refresh(document: codeFile, selection: activeTextView?.selectedRange())
            #if DEBUG
            debugRuntimeLog("CodeFileView appeared length=\(codeFile.content?.length ?? 0) editable=\(isEditable)")
            debugRuntimeLog("Plain editor toolbar ready")
            debugRuntimeLog("Plain editor status bar ready")
            logFontSettings()
            #endif
        }
        .onChange(of: editorFontFamily) { _, _ in
            logFontSettings()
        }
        .onChange(of: editorFontSize) { _, _ in
            logFontSettings()
        }
        .onChange(of: editorThemeName) { _, _ in
            if let activeTextView {
                PlainSyntaxHighlighter.highlight(textView: activeTextView, language: codeFile.getLanguage())
            } else if let storage = codeFile.content {
                PlainSyntaxHighlighter.highlight(storage: storage, language: codeFile.getLanguage())
            }
        }
        // The external-change conflict surface. Driven entirely by the
        // document's observable pendingExternalChange state, so the prompt is
        // SwiftUI-side on this window's scene with no AppKit NSAlert.
        .alert(
            externalChangeAlertTitle(for: codeFile.pendingExternalChange),
            isPresented: Binding(
                get: { codeFile.pendingExternalChange != nil },
                set: { presented in
                    // SwiftUI drives this false after a button; treat any external
                    // dismissal of a resolvable conflict as "keep my edits" (no data
                    // loss). The buttons themselves resolve/dismiss explicitly.
                    if !presented { codeFile.dismissExternalChangeAlert() }
                }
            ),
            presenting: codeFile.pendingExternalChange
        ) { prompt in
            externalChangeAlertButtons(for: prompt)
        } message: { prompt in
            Text(externalChangeAlertMessage(for: prompt))
        }
    }

    // Per-window enabled state for the native toolbar. Save tracks the document's
    // dirty flag; undo, redo, and Clean Text track this window's own active text
    // view, matching the same-named Commands-menu items so a toolbar click and a
    // menu command agree.
    private var canSave: Bool { codeFile.isDocumentEdited }
    private var canUndo: Bool { activeTextView?.undoManager?.canUndo ?? false }
    private var canRedo: Bool { activeTextView?.undoManager?.canRedo ?? false }
    private var canCleanText: Bool { activeTextView?.isEditable ?? false }

    // The window's native macOS 26 Liquid Glass toolbar (top chrome). These are
    // standard system toolbar controls, so the OS applies grouped rounded-capsule
    // Liquid Glass automatically (docs/LIQUID_GLASS.md sections 1-2); no glass is
    // hand-applied here. Each ToolbarItemGroup is one capsule cluster. Every button
    // is a pure click target that calls the exact ShellDocumentActions /
    // EditorCommandRouter function the Commands menu calls, against this window's own
    // activeTextView, with the same enabled state. Keyboard shortcuts stay on the
    // Commands menu (EditorCommands.swift); toolbar items carry none.
    @ToolbarContentBuilder
    private func editorToolbar() -> some ToolbarContent {
        // Explicit `.navigation` placement docks each group at the toolbar's leading
        // edge, right after the traffic lights, instead of the trailing cluster the
        // system's default `.automatic` placement produces. This is what makes the row
        // read left-aligned like the Kate reference, rather than floated to the right.
        ToolbarItemGroup(placement: .navigation) {
            Button {
                ShellDocumentActions.newDocument()
            } label: {
                ToolbarButtonLabel(title: "New", systemImage: "doc.badge.plus")
            }
            Button {
                ShellDocumentActions.openDocumentWithPanel()
            } label: {
                ToolbarButtonLabel(title: "Open", systemImage: "folder")
            }
        }
        ToolbarItemGroup(placement: .navigation) {
            Button {
                ShellDocumentActions.saveActiveDocument()
            } label: {
                ToolbarButtonLabel(title: "Save", systemImage: "square.and.arrow.down")
            }
            .disabled(!canSave)
            Button {
                ShellDocumentActions.saveActiveDocumentAs()
            } label: {
                ToolbarButtonLabel(title: "Save As", systemImage: "square.and.arrow.down.on.square")
            }
            .disabled(!canSave)
        }
        ToolbarItemGroup(placement: .navigation) {
            Button {
                if let activeTextView { _ = EditorCommandRouter.shared.undo(on: activeTextView) }
            } label: {
                ToolbarButtonLabel(title: "Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!canUndo)
            Button {
                if let activeTextView { _ = EditorCommandRouter.shared.redo(on: activeTextView) }
            } label: {
                ToolbarButtonLabel(title: "Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!canRedo)
        }
        ToolbarItemGroup(placement: .navigation) {
            Button {
                if let activeTextView { _ = EditorCommandRouter.shared.cleanText(on: activeTextView) }
            } label: {
                ToolbarButtonLabel(title: "Clean Text", systemImage: "wand.and.sparkles")
            }
            .disabled(!canCleanText)
        }
    }

    private func externalChangeAlertTitle(for prompt: CodeFileDocument.ExternalChangePrompt?) -> String {
        switch prompt {
        case .reloadConflict:
            return "This file has changed on disk"
        case .undecodable:
            return "This file changed to an unsupported encoding"
        case .fileDeleted:
            return "This file was deleted or moved"
        case nil:
            return ""
        }
    }

    @ViewBuilder
    private func externalChangeAlertButtons(
        for prompt: CodeFileDocument.ExternalChangePrompt
    ) -> some View {
        switch prompt {
        case .reloadConflict:
            Button("Keep My Edits", role: .cancel) {
                codeFile.resolveExternalChangeConflict(reloadFromDisk: false)
            }
            Button("Reload from Disk") {
                codeFile.resolveExternalChangeConflict(reloadFromDisk: true)
            }
        case .undecodable, .fileDeleted:
            Button("OK", role: .cancel) {
                codeFile.dismissExternalChangeAlert()
            }
        }
    }

    private func externalChangeAlertMessage(for prompt: CodeFileDocument.ExternalChangePrompt) -> String {
        switch prompt {
        case .reloadConflict:
            return "You have unsaved edits, and the file was changed by another program. "
                + "Keep your edits, or reload the version on disk and discard them."
        case .undecodable:
            return "The new contents on disk are not valid text in a supported encoding, "
                + "so they were not loaded. Your open document is unchanged."
        case .fileDeleted:
            return "Your edits are kept in this window. Use Save As to write them to a new file."
        }
    }

    private func logFontSettings() {
        #if DEBUG
        debugRuntimeLog("Plain editor font settings: family=\(editorFontFamily) size=\(editorFontSize)")
        #endif
    }
}

// A native `Label(_:systemImage:)` toolbar item is decomposed by the SwiftUI/
// AppKit toolbar bridge into NSToolbarItem's built-in image and title, which
// the system's icon-and-label display mode stacks vertically (icon above,
// text below) -- the tall look this toolbar is meant to avoid (Kate-style
// layout). This view is a fully custom SwiftUI toolbar item instead, so AppKit
// keeps the horizontal layout as authored: icon beside text, one compact row,
// matching the reference. The native toolbar container (and its automatic
// Liquid Glass grouping) is unaffected; only this item's internal label
// layout is customized.
private struct ToolbarButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
        }
    }
}

enum PlainEditorFontSettings {
    static let defaultFontFamily = "SF Mono"
    static let defaultFontSize = 13.0
    static let minimumFontSize = 9.0
    static let maximumFontSize = 32.0

    /// The fixed-pitch families the font picker offers, enumerated live from
    /// the installed system fonts so a newly installed monospace
    /// font shows up without a rebuild. `defaultFontFamily` is guaranteed to
    /// be present even if CoreText's family enumeration does not surface it
    /// as a distinct family name on this system, since it must always
    /// remain a selectable, working default.
    static var availableFontFamilies: [String] {
        var families = PlainEditorFontEnumeration.installedFixedPitchFamilies()
        if !families.contains(defaultFontFamily) {
            families.insert(defaultFontFamily, at: 0)
        }
        return families
    }

    static func font(family: String, size: Double) -> NSFont {
        let clampedSize = min(max(size, minimumFontSize), maximumFontSize)
        if family == defaultFontFamily {
            return .monospacedSystemFont(ofSize: clampedSize, weight: .regular)
        }
        guard let font = NSFont(name: family, size: clampedSize), font.isFixedPitch else {
            return .monospacedSystemFont(ofSize: clampedSize, weight: .regular)
        }
        return font
    }

    /// The next font size after growing by one step, clamped to
    /// `maximumFontSize`. Called by the Format menu's Increase Size item.
    static func increasedFontSize(from current: Double) -> Double {
        min(maximumFontSize, current + 1)
    }

    /// The next font size after shrinking by one step, clamped to
    /// `minimumFontSize`. Called by the Format menu's Decrease Size item.
    static func decreasedFontSize(from current: Double) -> Double {
        max(minimumFontSize, current - 1)
    }
}

#if DEBUG
@MainActor
private enum PlainEditorCommandSelfTest {
    private static var didSchedule = false

    static func scheduleIfRequested(textView: TextView) {
        guard ProcessInfo.processInfo.environment["CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST"] == "1",
              !didSchedule else {
            return
        }
        didSchedule = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            run(textView: textView)
        }
    }

    private static func run(textView: TextView) {
        let originalText = textView.string
        let originalSelection = textView.selectedRange()
        let originalPasteboard = NSPasteboard.general.string(forType: .string)
        let marker = "let plainEditorCommandSelfTestValue = 123\n"

        textView.window?.makeFirstResponder(textView)
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        textView.replaceCharacters(in: NSRange(location: 0, length: 0), with: marker)
        let inserted = textView.string.hasPrefix(marker)

        let undoSent = EditorCommandRouter.shared.undo()
        let undoWorked = undoSent && textView.string == originalText

        let redoSent = EditorCommandRouter.shared.redo()
        let redoWorked = redoSent && textView.string.hasPrefix(marker)

        let selectAllSent = EditorCommandRouter.shared.selectAll()
        let selectedAll = selectAllSent && textView.selectedRange().length == (textView.string as NSString).length

        // Copy value A (the marker) to the system pasteboard.
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: (marker as NSString).length))
        let copySent = EditorCommandRouter.shared.copy()
        let copied = copySent && NSPasteboard.general.string(forType: .string) == marker

        // Cut a distinct value B so the pasteboard now holds B, not the copied A.
        // Paste must then yield B, proving paste reads the live pasteboard and not a
        // stale internal copy buffer (regression guard for the paste-ordering bug).
        let cutMarker = "let plainEditorCommandCutValue = 456\n"
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        textView.replaceCharacters(in: NSRange(location: 0, length: 0), with: cutMarker)
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: (cutMarker as NSString).length))
        let cutSent = EditorCommandRouter.shared.cut()
        let cut = cutSent && !textView.string.hasPrefix(cutMarker)

        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        let pasteSent = EditorCommandRouter.shared.paste()
        let pasted = pasteSent && textView.string.hasPrefix(cutMarker)

        let dirtyLine = "let cleanTextSmokeValue = 1    \n"
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        textView.replaceCharacters(in: NSRange(location: 0, length: 0), with: dirtyLine)
        let cleanSent = EditorCommandRouter.shared.cleanText()
        let cleanWorked = cleanSent && textView.string.hasPrefix("let cleanTextSmokeValue = 1\n")
        let cleanUndoSent = EditorCommandRouter.shared.undo()
        let cleanUndoWorked = cleanUndoSent && textView.string.hasPrefix(dirtyLine)
        let cleanRedoSent = EditorCommandRouter.shared.redo()
        let cleanRedoWorked = cleanRedoSent && textView.string.hasPrefix("let cleanTextSmokeValue = 1\n")

        // Exercise the five Clean Text actions. Each check
        // replaces the whole document with a small dedicated fixture, since
        // these actions (unlike cleanText's prefix check above) need control
        // of the whole document to prove line-ending, final-newline, and
        // indentation behavior; the final restore below resets the document
        // regardless of this intermediate content.
        let fullRange = { NSRange(location: 0, length: (textView.string as NSString).length) }

        textView.replaceCharacters(in: fullRange(), with: "let cleanLineEndingsSmokeValue = 1\r\nsecond line\r\n")
        let cleanLineEndingsSent = EditorCommandRouter.shared.cleanLineEndingsToLF()
        let cleanLineEndingsWorked = cleanLineEndingsSent
            && textView.string == "let cleanLineEndingsSmokeValue = 1\nsecond line\n"

        textView.replaceCharacters(in: fullRange(), with: "let cleanFinalNewlineSmokeValue = 1")
        let cleanFinalNewlineSent = EditorCommandRouter.shared.cleanFinalNewline()
        let cleanFinalNewlineWorked = cleanFinalNewlineSent
            && textView.string == "let cleanFinalNewlineSmokeValue = 1\n"

        textView.replaceCharacters(in: fullRange(), with: "\tlet cleanTabsToSpacesSmokeValue = 1\n")
        let cleanTabsToSpacesSent = EditorCommandRouter.shared.cleanTabsToSpaces()
        let cleanTabsToSpacesWorked = cleanTabsToSpacesSent
            && textView.string.hasPrefix("    let cleanTabsToSpacesSmokeValue")

        textView.replaceCharacters(in: fullRange(), with: "    let cleanSpacesToTabsSmokeValue = 1\n")
        let cleanSpacesToTabsSent = EditorCommandRouter.shared.cleanSpacesToTabs()
        let cleanSpacesToTabsWorked = cleanSpacesToTabsSent
            && textView.string.hasPrefix("\tlet cleanSpacesToTabsSmokeValue")

        textView.replaceCharacters(in: fullRange(), with: "let cleanSmartPunctSmokeValue = \u{201C}x\u{201D}\n")
        let cleanSmartPunctSent = EditorCommandRouter.shared.cleanSmartPunctuationToASCII()
        let cleanSmartPunctWorked = cleanSmartPunctSent && textView.string.contains("\"x\"")

        // Built as concatenated segments (rather than one long interpolated literal) so the
        // line stays under SwiftLint's length limit; the emitted marker string is unchanged.
        var selfTestMarker = "Plain editor command self-test: insert=\(inserted) undo=\(undoWorked)"
        selfTestMarker += " redo=\(redoWorked) selectAll=\(selectedAll) copy=\(copied) cut=\(cut)"
        selfTestMarker += " paste=\(pasted) cleanText=\(cleanWorked) cleanUndo=\(cleanUndoWorked)"
        selfTestMarker += " cleanRedo=\(cleanRedoWorked) cleanLineEndings=\(cleanLineEndingsWorked)"
        selfTestMarker += " cleanFinalNewline=\(cleanFinalNewlineWorked) cleanTabsToSpaces=\(cleanTabsToSpacesWorked)"
        selfTestMarker += " cleanSpacesToTabs=\(cleanSpacesToTabsWorked) cleanSmartPunct=\(cleanSmartPunctWorked)"
        debugRuntimeLog(selfTestMarker)

        let currentFullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.replaceCharacters(in: currentFullRange, with: originalText)
        let restoredSelection = if originalSelection.location != NSNotFound,
                                   originalSelection.location <= textView.textStorage.length {
            NSRange(
                location: originalSelection.location,
                length: min(originalSelection.length, textView.textStorage.length - originalSelection.location)
            )
        } else {
            NSRange(location: 0, length: 0)
        }
        textView.selectionManager.setSelectedRange(restoredSelection)

        NSPasteboard.general.clearContents()
        if let originalPasteboard {
            NSPasteboard.general.setString(originalPasteboard, forType: .string)
        }
    }
}
#endif

@MainActor
final class PlainEditorChromeModel: ObservableObject {
    @Published var cursorPosition = "--"
    @Published var lineCount = "--"
    @Published var wordCount = "--"
    @Published var characterCount = "--"
    @Published var indentation = "--"
    @Published var encoding = "--"
    @Published var lineEnding = "--"
    @Published var syntaxMode = "--"

    // The debounce window for the O(n) full-document counts. A quiet period this
    // long after the last edit triggers one recompute; sustained typing keeps
    // cancelling and rescheduling it, so the whole document is never rescanned on
    // the keystroke hot path (the measured ~2 s per-keystroke floor this fixes).
    private static let recomputeDebounce = Duration.milliseconds(150)

    // Total line count, refreshed by the heavy recompute and reused as the cursor
    // label denominator so a plain cursor move never rescans the whole document.
    private var cachedTotalLines = 1
    // Line-start UTF-16 offset index, refreshed alongside cachedTotalLines by the
    // heavy recompute. cursorLabel binary-searches this array for the
    // cursor's line number instead of counting line breaks from offset 0, so the
    // cheap keystroke path never rescans from the start of the document. Like
    // cachedTotalLines, this can be up to one debounce cycle (150 ms) stale
    // between edits: a transiently-stale index still indexes safely into the
    // cached array (never out of bounds) and self-corrects once the debounced
    // recompute runs, so at worst the label briefly shows the pre-edit line
    // number rather than crashing or showing an unbounded value. Defaults to a
    // single empty line to match cachedTotalLines' default before any document
    // has been through a full recompute.
    private var cachedLineStartIndex = [0]
    // The most recent selection, so the debounced recompute can re-emit the cursor
    // label against the freshly recomputed total line count.
    private var lastSelection = NSRange(location: 0, length: 0)
    // In-flight debounced recompute; cancelled and rescheduled on each edit.
    private var recomputeTask: Task<Void, Never>?

    // Full synchronous refresh for initial load, external reload, and onAppear, so
    // the status bar is correct the moment a document opens rather than after the
    // first debounce.
    func refresh(document: CodeFileDocument, selection: NSRange?) {
        recomputeTask?.cancel()
        lastSelection = selection ?? NSRange(location: 0, length: 0)
        recomputeAll(document: document, selection: lastSelection)
    }

    // A text edit: update the cheap metrics (cursor label, character count) now and
    // debounce the O(n) counts. Called from the editor's onTextChange.
    func refreshForEdit(document: CodeFileDocument, selection: NSRange?) {
        lastSelection = selection ?? lastSelection
        updateCheapMetrics(document: document, selection: lastSelection)
        scheduleHeavyRecompute(document: document)
    }

    // A cursor or selection move with no text change: only the cursor label can
    // change. Called from the editor's onSelectionChange.
    func refreshForSelectionChange(document: CodeFileDocument, selection: NSRange?) {
        lastSelection = selection ?? lastSelection
        updateCheapMetrics(document: document, selection: lastSelection)
    }

    // Recomputes the O(n) counts first (which refreshes cachedTotalLines), then the
    // cheap metrics so the cursor label picks up the fresh denominator, then emits
    // the smoke marker with complete data.
    private func recomputeAll(document: CodeFileDocument, selection: NSRange) {
        updateHeavyMetrics(document: document)
        updateCheapMetrics(document: document, selection: selection)
        emitStatusMarker()
    }

    // Cheap, immediate metrics: encoding and syntax are O(1) enum lookups and the
    // character count is the storage length. The cursor label is the only bounded
    // scan left, and that scan is an O(log lines) binary search into
    // the cached line-start index plus an O(line length) column scan, so it is
    // cheap enough to recompute on every call. It deliberately always runs against
    // the current cache with no cursor-signature dedup: the earlier dedup
    // keyed on scalar counts (location, length, documentLength, totalLines) that
    // stay equal across an equal-length edit which merely relocates a line break,
    // so a stale-cache label could survive a debounced cache refresh (the rebuilt
    // signature matched and the recompute was skipped). Recomputing unconditionally
    // removes that whole bug class -- no signature can go stale if there is none.
    private func updateCheapMetrics(document: CodeFileDocument, selection: NSRange) {
        encoding = PlainEditorStatusReporter.encodingLabel(document.sourceEncoding)
        syntaxMode = PlainEditorStatusReporter.languageLabel(document.getLanguage())

        guard let storage = document.content else {
            cursorPosition = "--"
            characterCount = "--"
            return
        }

        let documentLength = storage.length
        characterCount = "\(documentLength) characters"

        #if DEBUG
        let scanStart = DispatchTime.now()
        #endif
        // mutableString is the live backing store; reading it avoids bridging a
        // fresh Swift String copy of the whole document on every keystroke.
        cursorPosition = PlainEditorStatusReporter.cursorLabel(
            text: storage.mutableString,
            selection: selection,
            totalLines: cachedTotalLines,
            lineStartIndex: cachedLineStartIndex
        )
        #if DEBUG
        // STATUS_REFRESH_MS isolates the status subsystem's synchronous keystroke
        // cost from the highlight cost the keystroke bench measures, so a future
        // regression here is attributable. It times only the bounded cursor
        // scan, which is the sole O(document) work left on the hot path.
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - scanStart.uptimeNanoseconds) / 1_000_000
        debugRuntimeLog("STATUS_REFRESH_MS=\(elapsedMs)")
        #endif
    }

    // The O(n) counts, run synchronously on the full path and on the debounce.
    private func updateHeavyMetrics(document: CodeFileDocument) {
        guard let storage = document.content else {
            lineCount = "--"
            wordCount = "--"
            indentation = "--"
            lineEnding = "--"
            return
        }
        let nsText = storage.mutableString
        let lines = PlainEditorStatusReporter.lineCount(in: nsText)
        cachedTotalLines = lines
        // Built alongside cachedTotalLines so cursorLabel's immediate path
        // never scans from offset 0 for the cursor's line number.
        cachedLineStartIndex = PlainEditorStatusReporter.lineStartIndex(in: nsText)
        lineCount = "\(max(1, lines)) lines"
        wordCount = "\(PlainEditorStatusReporter.wordCount(in: nsText)) words"
        indentation = PlainEditorStatusReporter.indentationLabel(in: nsText)
        lineEnding = PlainEditorStatusReporter.lineEndingLabel(in: nsText)
    }

    // Debounced recompute: cancellable main-actor work that runs the O(n) counts
    // once the edits go quiet, then re-emits the cursor label and status marker.
    private func scheduleHeavyRecompute(document: CodeFileDocument) {
        recomputeTask?.cancel()
        recomputeTask = Task { @MainActor [weak self, weak document] in
            try? await Task.sleep(for: PlainEditorChromeModel.recomputeDebounce)
            guard !Task.isCancelled, let self, let document else {
                return
            }
            self.recomputeAll(document: document, selection: self.lastSelection)
        }
    }

    #if DEBUG
    // Test-only synchronous entry point to the debounced heavy-recompute body.
    // The release path runs this same recomputeAll off a 150 ms Task (see
    // scheduleHeavyRecompute); a test cannot deterministically await that Task,
    // so this drives the identical work directly: it cancels any pending debounce
    // and recomputes against the most recent selection, exactly as the debounce
    // does, without bumping any edit state. This lets a test observe the label the
    // status bar settles on at rest. Never called on the release hot path.
    func drainHeavyRecomputeForTesting(document: CodeFileDocument) {
        recomputeTask?.cancel()
        recomputeAll(document: document, selection: lastSelection)
    }
    #endif

    private func emitStatusMarker() {
        #if DEBUG
        // Built as concatenated segments (rather than one long interpolated literal) so the
        // line stays under SwiftLint's length limit; the emitted marker string is unchanged.
        var statusMarker = "Plain editor status: cursor=\(cursorPosition) lines=\(lineCount)"
        statusMarker += " words=\(wordCount) chars=\(characterCount) indent=\(indentation)"
        statusMarker += " encoding=\(encoding) lineEnding=\(lineEnding) syntax=\(syntaxMode)"
        debugRuntimeLog(statusMarker)
        #endif
    }

}

#if DEBUG
/// DEBUG-only environment key letting an automated capture force
/// `PlainEditorStatusBar`'s reduce-transparency fallback. `nil` means "no
/// override"; the status bar then falls back to the real, live-tracked
/// `\.accessibilityReduceTransparency` value. SwiftUI does not expose a
/// writable key path for `\.accessibilityReduceTransparency` itself, so this
/// app-local key is the override seam instead (set from
/// CodeFileDocumentBridge.swift).
private struct ForcedReduceTransparencyKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    var forcedReduceTransparencyForStatusBar: Bool? {
        get { self[ForcedReduceTransparencyKey.self] }
        set { self[ForcedReduceTransparencyKey.self] = newValue }
    }
}
#endif

private struct PlainEditorStatusBar: View {
    @ObservedObject var chrome: PlainEditorChromeModel
    @Environment(\.colorScheme) private var colorScheme
    // Reduce Transparency fallback (docs/LIQUID_GLASS.md section 12 point 1: this
    // is the single highest-value fix, since it honors every user who already told
    // the system they need it).
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    #if DEBUG
    @Environment(\.forcedReduceTransparencyForStatusBar) private var forcedReduceTransparencyForStatusBar
    #endif

    // The reduce-transparency state actually rendered: the forced override when an
    // automated capture set one, otherwise the real system value.
    private var effectiveReduceTransparency: Bool {
        #if DEBUG
        return forcedReduceTransparencyForStatusBar ?? reduceTransparency
        #else
        return reduceTransparency
        #endif
    }

    var body: some View {
        // Status bar is the control layer (docs/LIQUID_GLASS.md sections 2/5): it owns
        // its own custom Liquid Glass as the bottom counterpart to the native toolbar's
        // top chrome. The two never stack, so each samples the content between them.
        // Tinted per scheme so the glass has a gentle accent to
        // refract instead of reading as plain white/black
        // (docs/active_plans/reports/wp_g2_glass_evidence_report.md).
        if effectiveReduceTransparency {
            statusBarContent
                .background(opaqueTintedFill)
        } else {
            statusBarContent
                .glassEffect(.regular.tint(glassTint), in: Rectangle())
        }
    }

    private var statusBarContent: some View {
        HStack(spacing: 14) {
            Text(chrome.cursorPosition)
            Text(chrome.lineCount)
            Text(chrome.wordCount)
            Text(chrome.characterCount)
            Text(chrome.indentation)
            Text(chrome.encoding)
            Text(chrome.lineEnding)
            Text(chrome.syntaxMode)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Tuned separately per scheme: dark needs a stronger tint to read against a
    // dark backdrop, light needs a lighter touch to stay subtle.
    private var glassTint: Color {
        colorScheme == .dark
            ? Color.accentColor.opacity(0.10)
            : Color.accentColor.opacity(0.08)
    }

    // A fully opaque fallback fill: a solid neutral base with the same tint
    // layered on top, so nothing behind it can show through (unlike a plain
    // translucent color, which would still let content bleed through).
    private var opaqueTintedFill: some View {
        ZStack {
            Rectangle().fill(Color(nsColor: .windowBackgroundColor))
            Rectangle().fill(glassTint)
        }
    }
}
