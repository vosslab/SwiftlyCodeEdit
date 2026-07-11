//
//  BoundedRehighlightTests.swift
//  CodeEditTests
//
//  Created for the bounded rehighlight path.
//

import AppKit
import CodeEditHighlighting
import CodeEditLanguages
import Foundation
import Testing
@testable import CodeEdit

// The bounded rehighlight path reinterprets only a region around each
// edit instead of the whole document. These tests drive a document past the
// bounded-scheduling threshold, apply a range edit through the bounded entry
// point, and assert the edited line ends up colored exactly as a full-document
// highlight of the same final text would color it. That "in sync with the text"
// check is the correctness guarantee for typing, paste, undo, and Clean Text.
@Suite
@MainActor
struct BoundedRehighlightTests {
    init() {
        // The highlighter resolves the dark/light theme variant from
        // NSApp.effectiveAppearance; NSApp is nil until an NSApplication exists,
        // so touch the shared instance before any highlight pass runs.
        _ = NSApplication.shared
    }

    @Test
    func typingInsideALargeDocumentColorsTheEditedLineLikeAFullPass() async {
        let storage = makeLargeSwiftStorage()
        await fullyHighlight(storage: storage)

        // Insert a plain keyword-bearing line well inside the document, on its own
        // line so it never lands inside a multi-line construct.
        let insertionOffset = plainLineOffset(in: storage)
        let inserted = "let boundedRehighlightMarker = 4321\n"
        let editedRange = NSRange(location: insertionOffset, length: 0)
        storage.replaceCharacters(in: editedRange, with: inserted)

        PlainSyntaxHighlighter.rehighlight(
            storage: storage,
            language: .swift,
            editedRange: editedRange,
            newLength: (inserted as NSString).length
        )

        let insertedLine = NSRange(location: insertionOffset, length: (inserted as NSString).length)
        await waitForColoring(in: storage, range: insertedLine)

        // A full highlight of the identical final text is the reference coloring.
        let reference = NSTextStorage(string: storage.string)
        await fullyHighlight(storage: reference)

        #expect(distinctForegroundColorCount(in: storage, range: insertedLine) >= 2)
        #expect(
            foregroundColorSequence(in: storage, range: insertedLine)
                == foregroundColorSequence(in: reference, range: insertedLine)
        )
    }

    @Test
    func undoOfAnInsertionRestoresTheOriginalColoring() async {
        let original = makeLargeSwiftStorage()
        let originalText = original.string
        let storage = makeLargeSwiftStorage()
        await fullyHighlight(storage: storage)

        let insertionOffset = plainLineOffset(in: storage)
        let inserted = "let undoBoundedMarker = 99\n"
        let insertRange = NSRange(location: insertionOffset, length: 0)
        storage.replaceCharacters(in: insertRange, with: inserted)
        PlainSyntaxHighlighter.rehighlight(
            storage: storage,
            language: .swift,
            editedRange: insertRange,
            newLength: (inserted as NSString).length
        )
        await waitForColoring(in: storage, range: NSRange(location: insertionOffset, length: (inserted as NSString).length))

        // Undo replays as a range edit that removes the inserted text; the bounded
        // path repaints the region back to its pre-edit coloring.
        let undoRange = NSRange(location: insertionOffset, length: (inserted as NSString).length)
        storage.replaceCharacters(in: undoRange, with: "")
        PlainSyntaxHighlighter.rehighlight(
            storage: storage,
            language: .swift,
            editedRange: undoRange,
            newLength: 0
        )

        #expect(storage.string == originalText)

        let checkLine = original.mutableString.lineRange(for: NSRange(location: insertionOffset, length: 0))
        await waitForColoring(in: storage, range: checkLine)

        let reference = NSTextStorage(string: originalText)
        await fullyHighlight(storage: reference)
        #expect(
            foregroundColorSequence(in: storage, range: checkLine)
                == foregroundColorSequence(in: reference, range: checkLine)
        )
    }

    @Test
    func wholeBufferRangeEditHighlightsTheEntireDocument() async {
        // Clean Text arrives as a range edit that replaces the whole buffer. The
        // bounded scheduler treats a whole-document region as a full highlight, so
        // the entire document ends up colored, not just a window.
        let storage = makeLargeSwiftStorage()
        let originalLength = storage.length
        let cleaned = storage.string + "\nlet cleanTextTailMarker = 7\n"
        storage.replaceCharacters(in: NSRange(location: 0, length: originalLength), with: cleaned)

        PlainSyntaxHighlighter.rehighlight(
            storage: storage,
            language: .swift,
            editedRange: NSRange(location: 0, length: originalLength),
            newLength: (cleaned as NSString).length
        )

        // Colored somewhere near the end proves the whole document was highlighted,
        // not just a leading window.
        let tail = NSRange(location: max(0, storage.length - 400), length: min(400, storage.length))
        await waitForColoring(in: storage, range: tail)
        #expect(distinctForegroundColorCount(in: storage, range: tail) >= 2)
    }

    // MARK: - Helpers

    // A Swift document comfortably past `boundedMinimumDocumentLength` so the
    // bounded scheduling path (not the small-document full path) runs. Simple
    // function blocks only, so every line starts at the interpreter's root
    // context and a bounded region colors identically to a full pass.
    private func makeLargeSwiftStorage() -> NSTextStorage {
        var text = ""
        var index = 0
        while (text as NSString).length < 60_000 {
            text += "func boundedSample\(index)(value: Int) -> Int {\n"
            text += "    let doubled = value * 2\n"
            text += "    return doubled + \(index)\n"
            text += "}\n\n"
            index += 1
        }
        return NSTextStorage(string: text)
    }

    // The offset at the start of a plain code line near the document middle, well
    // inside the edited-line window and never inside a multi-line construct.
    private func plainLineOffset(in storage: NSTextStorage) -> Int {
        let middle = storage.length / 2
        return storage.mutableString.lineRange(for: NSRange(location: middle, length: 0)).location
    }

    private func fullyHighlight(storage: NSTextStorage) async {
        PlainSyntaxHighlighter.highlight(storage: storage, language: .swift)
        let fullRange = NSRange(location: 0, length: storage.length)
        await waitForColoring(in: storage, range: fullRange)
    }

    // Polls the main actor until the range carries more than the base color, so a
    // regression fails (times out) instead of racing the async apply.
    private func waitForColoring(in storage: NSTextStorage, range: NSRange) async {
        for _ in 0..<500 {
            if distinctForegroundColorCount(in: storage, range: range) >= 2 {
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func distinctForegroundColorCount(in storage: NSTextStorage, range: NSRange) -> Int {
        var colors: Set<NSColor> = []
        storage.enumerateAttribute(.foregroundColor, in: range) { value, _, _ in
            if let color = value as? NSColor {
                colors.insert(color)
            }
        }
        return colors.count
    }

    // A per-character foreground-color sequence over `range`, so two storages can
    // be compared position by position (a sequence match proves the colors line up
    // with the text, not just that the same color set appears somewhere).
    private func foregroundColorSequence(in storage: NSTextStorage, range: NSRange) -> [String] {
        var sequence: [String] = []
        let clampedLength = min(range.length, storage.length - range.location)
        guard range.location >= 0, clampedLength > 0 else { return sequence }
        for offset in 0..<clampedLength {
            let charRange = NSRange(location: range.location + offset, length: 1)
            let color = storage.attribute(.foregroundColor, at: charRange.location, effectiveRange: nil) as? NSColor
            sequence.append(color.map { "\($0.redComponent),\($0.greenComponent),\($0.blueComponent)" } ?? "nil")
        }
        return sequence
    }
}
