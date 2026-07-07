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
    final class Coordinator: NSObject, TextViewDelegate {
        weak var textView: TextView?
        var onTextChange: (() -> Void)?

        func textView(_ textView: TextView, didReplaceContentsIn range: NSRange, with string: String) {
            onTextChange?()
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
        textView.edgeInsets = edgeInsets
        textView.textInsets = textInsets
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        textView.setUpScrollListeners(scrollView: scrollView)

        let controller = NSViewController()
        controller.view = scrollView
        context.coordinator.textView = textView
        context.coordinator.onTextChange = onTextChange

        return controller
    }

    func updateNSViewController(_ controller: NSViewController, context: Context) {
        guard let scrollView = controller.view as? NSScrollView,
              let textView = scrollView.documentView as? TextView else {
            return
        }

        context.coordinator.onTextChange = onTextChange

        if textView.string != textStorage.string {
            textView.setTextStorage(textStorage)
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
    }
}
