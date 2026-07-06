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
    final class Coordinator {
        weak var textView: TextView?
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

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.contentView.postsFrameChangedNotifications = true

        let controller = NSViewController()
        controller.view = scrollView
        context.coordinator.textView = textView

        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak textView, weak scrollView] _ in
            guard let textView, let scrollView else { return }
            textView.updatedViewport(scrollView.documentVisibleRect)
        }

        NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak textView, weak scrollView] _ in
            guard let textView, let scrollView else { return }
            textView.updatedViewport(scrollView.documentVisibleRect)
        }

        return controller
    }

    func updateNSViewController(_ controller: NSViewController, context: Context) {
        guard let scrollView = controller.view as? NSScrollView,
              let textView = scrollView.documentView as? TextView else {
            return
        }

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
