//
//  PlainTextEditorView.swift
//  CodeEdit
//
//  Created by Codex on 2026-07-06.
//

import AppKit
import SwiftUI
import CodeEditTextView

struct PlainTextEditorView: NSViewControllerRepresentable {
    final class EditorViewController: NSViewController {
        weak var textView: TextView?
        var didRequestInitialFirstResponder = false

        override func viewDidAppear() {
            super.viewDidAppear()
            guard let textView else { return }
            guard !didRequestInitialFirstResponder else { return }
            didRequestInitialFirstResponder = true
            view.window?.makeFirstResponder(textView)
        }
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency TextViewDelegate {
        weak var textView: TextView?
        var onTextChange: (() -> Void)?
        var onEdit: ((NSRange, Int) -> Void)?
        var onSelectionChange: ((NSRange) -> Void)?

        // Fires once per replaced range, including the per-mutation replays an
        // undo/redo drives through `replaceCharacters`. The range and replacement
        // length are the document's per-mutation change-tracking and edited-range
        // signal (`replacedRange` plus `newLength`); the coarser `onTextChange`
        // notification below drives idempotent whole-view refresh (highlight,
        // status, find) once per edit session.
        func textView(_ textView: TextView, didReplaceContentsIn range: NSRange, with string: String) {
            onEdit?(range, (string as NSString).length)
        }

        func attachNotifications(to textView: TextView) {
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSelectionChanged(_:)),
                name: TextSelectionManager.selectionChangedNotification,
                object: textView.selectionManager
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTextChanged(_:)),
                name: TextView.textDidChangeNotification,
                object: textView
            )
        }

        @objc
        func handleSelectionChanged(_ notification: Notification) {
            guard let textView else { return }
            onSelectionChange?(textView.selectedRange())
        }

        @objc
        func handleTextChanged(_ notification: Notification) {
            guard let textView else { return }
            onTextChange?()
            onSelectionChange?(textView.selectedRange())
        }
    }

    @Binding var textStorage: NSTextStorage
    var isEditable: Bool
    var isSelectable: Bool
    var wrapLines: Bool
    var useSystemCursor: Bool
    var font: NSFont
    var textColor: NSColor
    var lineHeightMultiplier: CGFloat
    var edgeInsets: HorizontalEdgeInsets
    var textInsets: HorizontalEdgeInsets
    var onTextChange: (() -> Void)?
    var onEdit: ((NSRange, Int) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?
    var onTextStorageReady: ((NSTextStorage) -> Void)?
    var onTextViewReady: ((TextView) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSViewController(context: Context) -> NSViewController {
        let textView = TextView(
            string: textStorage.string,
            font: font,
            textColor: textColor,
            lineHeightMultiplier: lineHeightMultiplier,
            wrapLines: wrapLines,
            isEditable: isEditable,
            isSelectable: isSelectable,
            useSystemCursor: useSystemCursor
        )
        textView.setTextStorage(textStorage)
        applyFont(to: textStorage)
        onTextStorageReady?(textStorage)
        textView.edgeInsets = edgeInsets
        textView.textInsets = textInsets
        textView.delegate = context.coordinator
        context.coordinator.attachNotifications(to: textView)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        textView.setUpScrollListeners(scrollView: scrollView)

        let controller = EditorViewController()
        controller.view = scrollView
        controller.textView = textView
        context.coordinator.textView = textView
        context.coordinator.onTextChange = onTextChange
        context.coordinator.onEdit = onEdit
        context.coordinator.onSelectionChange = onSelectionChange
        onTextViewReady?(textView)
        #if DEBUG
        debugRuntimeLog("PlainTextEditorView created editable=\(isEditable) length=\(textStorage.length)")
        #endif

        return controller
    }

    func updateNSViewController(_ controller: NSViewController, context: Context) {
        guard let scrollView = controller.view as? NSScrollView,
              let textView = scrollView.documentView as? TextView else {
            return
        }

        context.coordinator.onTextChange = onTextChange
        context.coordinator.onEdit = onEdit
        context.coordinator.onSelectionChange = onSelectionChange
        if context.coordinator.textView != nil {
            let textView = context.coordinator.textView!
            context.coordinator.attachNotifications(to: textView)
        }

        // Fire the storage-ready hook only when the backing store was actually
        // swapped (a new NSTextStorage replaced the old one). SwiftUI re-runs
        // updateNSViewController on every keystroke, so calling the hook here
        // unconditionally scheduled a whole-document highlight per edit that
        // superseded the bounded rehighlight -- the ~2 s fixed cost the
        // keystroke bench measured. A same-storage keystroke no longer reaches
        // the hook; the initial highlight runs from makeNSViewController and
        // reloads re-highlight through the document read path.
        let storageDidChange = textView.string != textStorage.string
        if storageDidChange {
            textView.setTextStorage(textStorage)
        }
        applyFont(to: textStorage)
        if storageDidChange {
            onTextStorageReady?(textStorage)
        }

        textView.isEditable = isEditable
        textView.isSelectable = isSelectable
        textView.wrapLines = wrapLines
        textView.useSystemCursor = useSystemCursor
        // This is the view-application site for the Settings scene's font
        // controls: compare against the font already on the live
        // text view before overwriting it, so the marker logs only after an
        // actual rendered-state change, never from the @AppStorage write
        // itself. The very first update after makeNSViewController already
        // set this same font, so creation never logs a spurious change.
        let previousFont = textView.font
        textView.font = font
        if previousFont.pointSize != font.pointSize {
            debugRuntimeLog("SETTINGS_APPLIED key=fontSize")
        }
        if previousFont.fontName != font.fontName {
            debugRuntimeLog("SETTINGS_APPLIED key=fontFamily")
        }
        textView.textColor = textColor
        textView.lineHeight = lineHeightMultiplier
        textView.edgeInsets = edgeInsets
        textView.textInsets = textInsets
        textView.updatedViewport(scrollView.documentVisibleRect)
        if controller.view.window?.firstResponder !== textView {
            controller.view.window?.makeFirstResponder(textView)
        }
        #if DEBUG
        debugRuntimeLog("PlainTextEditorView requested first responder editable=\(textView.isEditable)")
        #endif
    }

    private func applyFont(to storage: NSTextStorage) {
        let range = NSRange(location: 0, length: storage.length)
        guard range.length > 0 else { return }
        storage.addAttribute(.font, value: font, range: range)
    }
}
