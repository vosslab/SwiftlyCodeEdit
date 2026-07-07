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
        var onSelectionChange: ((NSRange) -> Void)?

        func textView(_ textView: TextView, didReplaceContentsIn range: NSRange, with string: String) {
            onTextChange?()
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

        @objc func handleSelectionChanged(_ notification: Notification) {
            guard let textView else { return }
            onSelectionChange?(textView.selectedRange())
        }

        @objc func handleTextChanged(_ notification: Notification) {
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
        context.coordinator.onSelectionChange = onSelectionChange
        if context.coordinator.textView != nil {
            let textView = context.coordinator.textView!
            context.coordinator.attachNotifications(to: textView)
        }

        if textView.string != textStorage.string {
            textView.setTextStorage(textStorage)
            onTextStorageReady?(textStorage)
        }

        textView.isEditable = isEditable
        textView.isSelectable = isSelectable
        textView.wrapLines = wrapLines
        textView.useSystemCursor = useSystemCursor
        textView.font = font
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
}
