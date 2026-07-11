//
//  EditorCommandRouterRoutingTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-10.
//
//  Covers the multi-window targeting fix in EditorCommandRouter: the
//  register/unregister lifecycle, key-window routing selection across two
//  registrants, and close-drops-entry behavior. Each test drives a fresh router
//  instance and real TextViews, asserting the command lands on the intended editor
//  by its observable text effect (undo reverting only the target's edit).
//

@testable import CodeEdit
import AppKit
import Foundation
import CodeEditTextView
import Testing

@MainActor
@Suite
struct EditorCommandRouterRoutingTests {
    // Builds an editor whose top edit is undoable: starting from `base`, it appends
    // `insert`, leaving `base + insert` with one edit on the undo stack. A router
    // `undo` on this editor reverts the text back to `base`.
    private func makeUndoableEditor(base: String, insert: String) -> TextView {
        let textView = TextView(string: "")
        textView.setTextStorage(NSTextStorage(string: base))
        textView.setUndoManager(CEUndoManager())
        textView.replaceCharacters(
            in: NSRange(location: (base as NSString).length, length: 0),
            with: insert
        )
        return textView
    }

    @Test
    func singleRegistrantResolvesWithoutActiveKey() {
        let editor = makeUndoableEditor(base: "hello", insert: " world")
        let router = EditorCommandRouter()
        router.register(textView: editor, for: ObjectIdentifier(editor))

        // Only one window is registered and no key-window event has arrived, yet the
        // menu path must still resolve to the sole editor.
        #expect(router.undo() == true)
        #expect(editor.string == "hello")
    }

    @Test
    func menuRoutesToKeyWindowEditor() {
        let first = makeUndoableEditor(base: "first", insert: "-A")
        let second = makeUndoableEditor(base: "second", insert: "-B")
        let router = EditorCommandRouter()
        let firstKey = ObjectIdentifier(first)
        let secondKey = ObjectIdentifier(second)
        router.register(textView: first, for: firstKey)
        router.register(textView: second, for: secondKey)

        // With the second window key, a menu undo must hit the second editor only.
        router.setActiveWindow(secondKey)
        #expect(router.undo() == true)
        #expect(second.string == "second")
        #expect(first.string == "first-A")

        // Refocusing the first window reroutes the next menu command to it, without
        // any re-registration.
        router.setActiveWindow(firstKey)
        #expect(router.undo() == true)
        #expect(first.string == "first")
    }

    @Test
    func closingKeyWindowDropsEntryAndReroutes() {
        let staying = makeUndoableEditor(base: "stay", insert: "-S")
        let closing = makeUndoableEditor(base: "close", insert: "-C")
        let router = EditorCommandRouter()
        let stayingKey = ObjectIdentifier(staying)
        let closingKey = ObjectIdentifier(closing)
        router.register(textView: staying, for: stayingKey)
        router.register(textView: closing, for: closingKey)
        router.setActiveWindow(closingKey)

        // The key window closes: its entry is dropped and the active key is cleared.
        router.unregister(for: closingKey)

        // The one remaining window is now the unambiguous target; the closed editor
        // is never touched.
        #expect(router.undo() == true)
        #expect(staying.string == "stay")
        #expect(closing.string == "close-C")
    }

    // MARK: - Clean Text actions are single undoable edits

    @Test
    func cleanLineEndingsToLFIsSingleUndoableOperation() {
        let textView = TextView(string: "")
        textView.setTextStorage(NSTextStorage(string: "one\r\ntwo\r\n"))
        textView.setUndoManager(CEUndoManager())
        let router = EditorCommandRouter()
        router.register(textView: textView, for: ObjectIdentifier(textView))

        #expect(router.cleanLineEndingsToLF() == true)
        #expect(textView.string == "one\ntwo\n")

        // Undoing once fully restores the original text: the whole-document
        // rewrite is one edit on the undo stack, not one edit per line ending.
        #expect(router.undo() == true)
        #expect(textView.string == "one\r\ntwo\r\n")
    }
}
