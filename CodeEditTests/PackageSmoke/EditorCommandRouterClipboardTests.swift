//
//  EditorCommandRouterClipboardTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-11.
//
//  Ports the clipboard coverage that used to live in
//  PlainEditorClipboardTests.swift (against the retired AppKit-shell
//  PlainEditorActionRouter) onto the live EditorCommandRouter, the shared action
//  router the SwiftUI shell's menu and toolbar both call. Uses a fresh router
//  instance registered against one TextView, mirroring
//  EditorCommandRouterRoutingTests.swift's pattern (single registrant resolves
//  without an active key).
//

@testable import CodeEdit
import AppKit
import Foundation
import CodeEditTextView
import Testing

@MainActor
@Suite(.serialized)
struct EditorCommandRouterClipboardTests {
    private func makeRegisteredEditor(string: String) -> (TextView, EditorCommandRouter) {
        let textView = TextView(string: string)
        let router = EditorCommandRouter()
        router.register(textView: textView, for: ObjectIdentifier(textView))
        return (textView, router)
    }

    @Test
    func copyThenCutThenPasteYieldsCutValue() {
        // Document holds A ("AAAA") followed by B ("BBBB").
        let (textView, router) = makeRegisteredEditor(string: "AAAABBBB")

        // Copy A to the system pasteboard.
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 4))
        #expect(router.copy())
        #expect(NSPasteboard.general.string(forType: .string) == "AAAA")

        // Cut B; cut writes the selection to the pasteboard, so it now holds B, not A.
        textView.selectionManager.setSelectedRange(NSRange(location: 4, length: 4))
        #expect(router.cut())
        #expect(NSPasteboard.general.string(forType: .string) == "BBBB")

        // Paste at the document start; the pasted value must be the cut value B.
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        #expect(router.paste())
        #expect(textView.string.hasPrefix("BBBB"))
    }

    @Test
    func pasteReadsExternalPasteboardContent() {
        let (textView, router) = makeRegisteredEditor(string: "hello world")

        // Copy the whole document; the pasteboard now holds "hello world".
        textView.selectionManager.setSelectedRange(
            NSRange(location: 0, length: (textView.string as NSString).length)
        )
        #expect(router.copy())

        // Another app copies different content into the system pasteboard.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("external clipboard text", forType: .string)

        // Paste must reflect the live pasteboard, not any earlier internal copy.
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        #expect(router.paste())
        #expect(textView.string.hasPrefix("external clipboard text"))
    }

    @Test
    func pasteIsNoOpWhenPasteboardIsEmpty() {
        let (textView, router) = makeRegisteredEditor(string: "content")

        NSPasteboard.general.clearContents()
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))

        // EditorCommandRouter.paste() always returns true once dispatched (see
        // EditorCommandRouter.swift's paste(on:) doc comment: "TextView.paste reads
        // the live pasteboard and no-ops when it holds no string"), unlike the
        // retired PlainEditorActionRouter.paste(), which checked the pasteboard and
        // returned false when empty. The functional contract worth pinning here is
        // that an empty pasteboard leaves the document unchanged.
        _ = router.paste()
        #expect(textView.string == "content")
    }
}
