//
//  PlainEditorClipboardTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-09.
//

@testable import CodeEdit
import AppKit
import Foundation
import CodeEditTextView
import Testing

@MainActor
@Suite(.serialized)
struct PlainEditorClipboardTests {
    private func makeRegisteredTextView(string: String) -> TextView {
        let textView = TextView(string: string)
        PlainEditorActionRouter.shared.register(textView: textView)
        return textView
    }

    @Test
    func copyThenCutThenPasteYieldsCutValue() {
        // Document holds A ("AAAA") followed by B ("BBBB").
        let textView = makeRegisteredTextView(string: "AAAABBBB")

        // Copy A to the system pasteboard.
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 4))
        #expect(PlainEditorActionRouter.shared.copy())
        #expect(NSPasteboard.general.string(forType: .string) == "AAAA")

        // Cut B; cut writes the selection to the pasteboard, so it now holds B, not A.
        textView.selectionManager.setSelectedRange(NSRange(location: 4, length: 4))
        #expect(PlainEditorActionRouter.shared.cut())
        #expect(NSPasteboard.general.string(forType: .string) == "BBBB")

        // Paste at the document start; the pasted value must be the cut value B.
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        #expect(PlainEditorActionRouter.shared.paste())
        #expect(textView.string.hasPrefix("BBBB"))
    }

    @Test
    func pasteReadsExternalPasteboardContent() {
        let textView = makeRegisteredTextView(string: "hello world")

        // Copy the whole document; the pasteboard now holds "hello world".
        textView.selectionManager.setSelectedRange(
            NSRange(location: 0, length: (textView.string as NSString).length)
        )
        #expect(PlainEditorActionRouter.shared.copy())

        // Another app copies different content into the system pasteboard.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("external clipboard text", forType: .string)

        // Paste must reflect the live pasteboard, not any earlier internal copy.
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        #expect(PlainEditorActionRouter.shared.paste())
        #expect(textView.string.hasPrefix("external clipboard text"))
    }

    @Test
    func pasteReturnsFalseWhenPasteboardIsEmpty() {
        let textView = makeRegisteredTextView(string: "content")

        NSPasteboard.general.clearContents()
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))

        #expect(PlainEditorActionRouter.shared.paste() == false)
        #expect(textView.string == "content")
    }
}
