//
//  UndoManagerRegistrationTests.swift
//  CodeEditTests
//
//  Created by Codex on 2026-07-07.
//

@testable import CodeEdit
import AppKit
import Foundation
import CodeEditTextView
import Testing

@MainActor
@Suite
struct UndoManagerRegistrationTests {
    let textView = TextView(string: "hello world")

    private final class DelegateRecorder: NSObject, TextViewDelegate {
        var didChangeCount = 0
        var lastRange: NSRange?

        func textView(_ textView: TextView, didReplaceContentsIn range: NSRange, with string: String) {
            didChangeCount += 1
            lastRange = range
        }
    }

    @Test
    func newUndoManager() {
        let manager = CEUndoManager()
        #expect(manager.canUndo == false)
    }

    @Test
    func undoManagerTracksMutations() throws {
        let manager = CEUndoManager()
        textView.setUndoManager(manager)
        manager.registerMutation(.init(string: "hello", range: NSRange(location: 0, length: 0), limit: 11))

        #expect(manager.canUndo)
    }

    @Test
    func typingAndUndoRedoUpdateTheTextView() {
        let recorder = DelegateRecorder()
        let manager = CEUndoManager()
        textView.setTextStorage(NSTextStorage(string: "hello"))
        textView.setUndoManager(manager)
        textView.delegate = recorder

        textView.replaceCharacters(in: NSRange(location: 5, length: 0), with: " world")

        #expect(textView.string == "hello world")
        #expect(recorder.didChangeCount == 1)
        #expect(recorder.lastRange == NSRange(location: 5, length: 0))
        #expect(manager.canUndo)
        #expect(manager.canRedo == false)

        manager.undo()
        #expect(textView.string == "hello")
        #expect(manager.canUndo == false)
        #expect(manager.canRedo)

        manager.redo()
        #expect(textView.string == "hello world")
        #expect(manager.canUndo)
        #expect(manager.canRedo == false)
    }
}
