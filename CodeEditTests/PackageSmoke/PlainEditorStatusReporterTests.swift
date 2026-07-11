//
//  PlainEditorStatusReporterTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-10.
//
//  Incremental status metrics. The status bar's O(n) counting functions
//  moved from Swift-String passes (whole-document splits plus a grapheme word
//  scan, the measured ~2 s per-keystroke floor) to bounded UTF-16 scans over the
//  editor's NSString backing store. These tests pin that the fast scans agree
//  with a brute-force oracle across the buffer shapes typing, paste, undo, and
//  Clean Text produce, and that the chrome model reports the counts it computes.
//

import Foundation
import Testing
@testable import CodeEdit

@Suite
struct PlainEditorStatusReporterTests {
    // Brute-force reference for word count: the original identifier-oriented
    // definition -- maximal runs of letters, digits, and underscore -- computed
    // with Swift's grapheme-aware split. Production replaces this with a UTF-16
    // scan, so this oracle pins that the scan still agrees with the obvious rule.
    private func referenceWordCount(_ text: String) -> Int {
        let words = text.split { !$0.isLetter && !$0.isNumber && $0 != "_" }
        return words.count
    }

    // The counts are a function of the final buffer text, so exercising the buffer
    // shapes that typing, paste, undo, and Clean Text leave behind covers the
    // acceptance requirement that counts stay correct after each of those.
    @Test
    func wordCountMatchesBruteForceOracleAcrossEditShapes() {
        let samples = [
            "let value = 1",                                            // typing
            "func sample_name(argument: Int) -> Int { return argument * 2 }",  // pasted block
            "",                                                         // undo back to empty
            "one\ntwo\nthree",                                          // multiline
            "let x = 1\nlet y = 2\n",                                   // Clean Text result
            "snake_case_identifier and camelCase123",                  // underscores keep one word
            "a,b;c.d  e\tf",                                            // dense separators
        ]
        for sample in samples {
            let counted = PlainEditorStatusReporter.wordCount(in: sample as NSString)
            #expect(counted == referenceWordCount(sample))
        }
    }

    @Test
    func lineCountCountsBreaksPlusOne() {
        #expect(PlainEditorStatusReporter.lineCount(in: "" as NSString) == 1)
        #expect(PlainEditorStatusReporter.lineCount(in: "one line" as NSString) == 1)
        #expect(PlainEditorStatusReporter.lineCount(in: "a\nb\nc" as NSString) == 3)
        // A trailing newline yields the conventional extra empty line.
        #expect(PlainEditorStatusReporter.lineCount(in: "a\nb\n" as NSString) == 3)
        // A CRLF pair is one break, so a Windows-lineending file is not doubled.
        #expect(PlainEditorStatusReporter.lineCount(in: "a\r\nb\r\nc" as NSString) == 3)
        #expect(PlainEditorStatusReporter.lineCount(in: "a\rb" as NSString) == 2)
    }

    // A CRLF placed so the CR ends one scan chunk and the LF starts the next pins
    // the carried-carriage-return path that keeps CRLF a single break across a
    // chunk boundary.
    @Test
    func lineCountHandlesCrlfAcrossChunkBoundary() {
        var text = String(repeating: "x", count: 8191)
        text += "\r\n"
        text += String(repeating: "y", count: 10)
        #expect(PlainEditorStatusReporter.lineCount(in: text as NSString) == 2)
    }

    @Test
    func cursorLabelReportsLineAndColumn() {
        let text = "abc\ndef\nghi" as NSString
        #expect(
            PlainEditorStatusReporter.cursorLabel(
                text: text, selection: NSRange(location: 0, length: 0), totalLines: 3
            ) == "1/3:1"
        )
        #expect(
            PlainEditorStatusReporter.cursorLabel(
                text: text, selection: NSRange(location: 6, length: 0), totalLines: 3
            ) == "2/3:3"
        )
        #expect(
            PlainEditorStatusReporter.cursorLabel(
                text: text, selection: NSRange(location: 11, length: 0), totalLines: 3
            ) == "3/3:4"
        )
    }

    // Edge case missing from the fixed-input case above: an empty document, the
    // state a brand-new or fully-cleared document is in.
    @Test
    func cursorLabelReportsFirstPositionForEmptyDocument() {
        #expect(
            PlainEditorStatusReporter.cursorLabel(
                text: "" as NSString, selection: NSRange(location: 0, length: 0), totalLines: 1
            ) == "1/1:1"
        )
    }

    // Edge case missing from the fixed-input case above: a document with no
    // trailing newline, cursor at the very end of the buffer.
    @Test
    func cursorLabelReportsEndOfBufferWithNoTrailingNewline() {
        let text = "abc\ndef" as NSString
        #expect(
            PlainEditorStatusReporter.cursorLabel(
                text: text, selection: NSRange(location: 7, length: 0), totalLines: 2
            ) == "2/2:4"
        )
    }

    @Test
    func lineEndingLabelDetectsStyleInPrecedenceOrder() {
        #expect(PlainEditorStatusReporter.lineEndingLabel(in: "a\r\nb" as NSString) == "CRLF")
        #expect(PlainEditorStatusReporter.lineEndingLabel(in: "a\rb" as NSString) == "CR")
        #expect(PlainEditorStatusReporter.lineEndingLabel(in: "a\nb" as NSString) == "LF")
        #expect(PlainEditorStatusReporter.lineEndingLabel(in: "abc" as NSString) == "Unknown")
    }

    @Test
    func indentationLabelReportsDominantStyle() {
        #expect(PlainEditorStatusReporter.indentationLabel(in: "\tfoo\n\tbar" as NSString) == "Tabs")
        #expect(PlainEditorStatusReporter.indentationLabel(in: "    foo\n    bar" as NSString) == "Soft Tabs: 4")
        #expect(PlainEditorStatusReporter.indentationLabel(in: "no indent here" as NSString) == "Unknown")
    }

    // Pins the chrome model wiring: a full refresh on a loaded document formats the
    // counts the reporter computes, so a regression in either the functions or the
    // formatting shows up here.
    @Test
    @MainActor
    func chromeRefreshReportsCountsForLoadedDocument() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appending(path: "counts.swift")
        let text = "let alpha = 1\nlet beta = 2\n"
        try text.write(to: sourceURL, atomically: true, encoding: .utf8)

        let codeFile = try CodeFileDocument(
            for: sourceURL, withContentsOf: sourceURL, ofType: "public.source-code"
        )
        let chrome = PlainEditorChromeModel()
        chrome.refresh(document: codeFile, selection: NSRange(location: 0, length: 0))

        #expect(chrome.characterCount == "\((text as NSString).length) characters")
        #expect(chrome.lineCount == "3 lines")
        #expect(chrome.wordCount == "6 words")
        #expect(chrome.cursorPosition == "1/3:1")
    }

    // Regression for the confirmed dedup bug: the cursor-label skip was keyed
    // only on (location, length, documentLength, totalLines), so an equal-length
    // edit entirely before the cursor -- one that leaves the raw cursor offset,
    // document length, and total line count all numerically unchanged while moving
    // where a newline sits inside that prefix -- produced a bit-identical
    // signature and kept a stale column. This is exactly the shape a Find/Replace
    // regex substitution leaves behind. Sequence: an edit refresh caches "2/2:3"
    // at offset 6 in "abc\ndefghi" (10 UTF-16 units); replacing the "abc\n" prefix
    // with the equal-length "xy\nz" yields "xy\nzdefghi" -- still 10 units, still
    // one line break, cursor still at offset 6 -- so the label must recompute to
    // "2/2:4" rather than stay "2/2:3".
    @Test
    @MainActor
    func cursorLabelRecomputesAfterEqualLengthEditBeforeCursor() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appending(path: "prefix_edit.txt")
        let text = "abc\ndefghi"
        try text.write(to: sourceURL, atomically: true, encoding: .utf8)

        let codeFile = try CodeFileDocument(
            for: sourceURL, withContentsOf: sourceURL, ofType: "public.plain-text"
        )
        let chrome = PlainEditorChromeModel()

        // Full refresh establishes the cached total-line denominator (2), then a
        // selection move to offset 6 caches the pre-edit cursor label.
        chrome.refresh(document: codeFile, selection: NSRange(location: 0, length: 0))
        chrome.refreshForSelectionChange(document: codeFile, selection: NSRange(location: 6, length: 0))
        #expect(chrome.cursorPosition == "2/2:3")

        // The equal-length edit entirely before the cursor: "abc\n" -> "xy\nz".
        codeFile.content?.replaceCharacters(in: NSRange(location: 0, length: 4), with: "xy\nz")
        chrome.refreshForEdit(document: codeFile, selection: NSRange(location: 6, length: 0))
        #expect(chrome.cursorPosition == "2/2:4")
    }

    // The cursor-label numerator moved from an O(cursor-offset) newline
    // count to a binary search into a cached line-start index. This pins the
    // index builder's recorded offsets against a fixed multiline sample.
    @Test
    func lineStartIndexRecordsEachLineStartOffset() {
        // "abc\ndef\nghi": line 1 at 0, line 2 at 4, line 3 at 8.
        let text = "abc\ndef\nghi" as NSString
        let index = PlainEditorStatusReporter.lineStartIndex(in: text)
        #expect(index == [0, 4, 8])
    }

    // Edge case: an empty document has exactly one (empty) line starting at 0.
    @Test
    func lineStartIndexHandlesEmptyDocument() {
        let index = PlainEditorStatusReporter.lineStartIndex(in: "" as NSString)
        #expect(index == [0])
    }

    // Edge case: no trailing newline still records the final line's start.
    @Test
    func lineStartIndexHandlesNoTrailingNewline() {
        let text = "abc\ndef" as NSString
        let index = PlainEditorStatusReporter.lineStartIndex(in: text)
        #expect(index == [0, 4])
    }

    // index.count and lineCount(in:) are two views of the same fact (one entry
    // per line); this pins that they agree across the lineCount oracle samples,
    // including CRLF and lone-CR line endings.
    @Test
    func lineStartIndexCountMatchesLineCount() {
        let samples = ["", "one line", "a\nb\nc", "a\nb\n", "a\r\nb\r\nc", "a\rb"]
        for sample in samples {
            let text = sample as NSString
            let index = PlainEditorStatusReporter.lineStartIndex(in: text)
            #expect(index.count == PlainEditorStatusReporter.lineCount(in: text))
        }
    }

    // The binary search must resolve an offset at a line's first character, an
    // offset mid-line, an offset at the very start of the document, and an
    // offset at the end of the document (one past the last character) to the
    // correct 1-based line number.
    @Test
    func lineNumberBinarySearchFindsLineAtStartMidAndEndOffsets() {
        // "abc\ndef\nghi": starts at 0, 4, 8; document length 11.
        let text = "abc\ndef\nghi" as NSString
        let index = PlainEditorStatusReporter.lineStartIndex(in: text)
        #expect(PlainEditorStatusReporter.lineNumber(forOffset: 0, lineStartIndex: index) == 1)
        // Offset at a line start.
        #expect(PlainEditorStatusReporter.lineNumber(forOffset: 4, lineStartIndex: index) == 2)
        // Offset mid-line.
        #expect(PlainEditorStatusReporter.lineNumber(forOffset: 6, lineStartIndex: index) == 2)
        // Offset at document end (one past the last character).
        #expect(PlainEditorStatusReporter.lineNumber(forOffset: text.length, lineStartIndex: index) == 3)
    }

    // Edge case: an empty document resolves offset 0 to line 1.
    @Test
    func lineNumberBinarySearchHandlesEmptyDocument() {
        let index = PlainEditorStatusReporter.lineStartIndex(in: "" as NSString)
        #expect(PlainEditorStatusReporter.lineNumber(forOffset: 0, lineStartIndex: index) == 1)
    }

    // Edge case: no trailing newline, cursor at the very end of the buffer.
    @Test
    func lineNumberBinarySearchHandlesNoTrailingNewline() {
        let text = "abc\ndef" as NSString
        let index = PlainEditorStatusReporter.lineStartIndex(in: text)
        #expect(PlainEditorStatusReporter.lineNumber(forOffset: text.length, lineStartIndex: index) == 2)
    }

    // The binary-search cursorLabel overload must produce exactly the same label
    // as the stateless O(cursor-offset) oracle for every offset across multiline
    // samples, so the numerator swap changes only computation cost, never
    // the reported label. Both an LF sample and a CRLF sample are checked so
    // Windows line endings are directly verified, not merely inferred: the one
    // offset that falls strictly between a CR and its LF is skipped because no
    // editor places a caret inside a CRLF pair (it is a single caret stop), and
    // the two line-number definitions legitimately disagree there -- the stateless
    // scan counts the CR as a completed break while the cached index records the
    // line start only after the full CRLF.
    @Test
    func cursorLabelWithCachedIndexMatchesStatelessOracle() {
        let samples = ["abc\ndef\nghi\njkl", "ab\r\ncd\r\nef"]
        for sample in samples {
            let text = sample as NSString
            let totalLines = PlainEditorStatusReporter.lineCount(in: text)
            let index = PlainEditorStatusReporter.lineStartIndex(in: text)
            for offset in 0...text.length {
                // Skip the interior of a CRLF pair (between the CR and its LF).
                if offset > 0 && offset < text.length
                    && text.character(at: offset - 1) == 0x0D
                    && text.character(at: offset) == 0x0A {
                    continue
                }
                let selection = NSRange(location: offset, length: 0)
                let oracle = PlainEditorStatusReporter.cursorLabel(
                    text: text, selection: selection, totalLines: totalLines
                )
                let cached = PlainEditorStatusReporter.cursorLabel(
                    text: text, selection: selection, totalLines: totalLines, lineStartIndex: index
                )
                #expect(cached == oracle)
            }
        }
    }

    // Regression for the confirmed stale-cache dedup bug found in review: the
    // cursor label could settle on a WRONG line at rest after an equal-length edit
    // that relocates a line break. The cheap keystroke path reads a cached
    // line-start index refreshed only on the 150 ms debounce, and the old
    // CursorSignature dedup keyed on scalar counts (location, length,
    // documentLength, totalLines, editGeneration) that all stay equal across such
    // an edit. Sequence: a full refresh caches lineStartIndex [0, 3] for
    // "ab\ncdefghi"; an equal-length "ab\ncd" -> "abcd\n" substitution makes
    // "abcd\nefghi" (still 10 units, one break, now at index 4) but only SCHEDULES
    // the heavy recompute, so the cache is still [0, 3]; a cursor move to offset 3
    // computes "2/2:4" against the stale [0, 3] and caches that signature; the
    // debounce then refreshes the cache to [0, 5] but totalLines is unchanged, so
    // the rebuilt signature matched and the recompute was skipped -- the wrong
    // "2/2:4" persisted at rest. The label must instead settle on "1/2:4". Drives
    // the debounce body through the DEBUG-only synchronous hook, the at-rest path
    // review found otherwise unexercised.
    @Test
    @MainActor
    func cursorLabelCorrectsStaleCacheOnDebouncedRecompute() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appending(path: "break_relocated.txt")
        let text = "ab\ncdefghi"
        try text.write(to: sourceURL, atomically: true, encoding: .utf8)

        let codeFile = try CodeFileDocument(
            for: sourceURL, withContentsOf: sourceURL, ofType: "public.plain-text"
        )
        let chrome = PlainEditorChromeModel()

        // Step 1: full refresh caches the line-start index [0, 3] and total lines 2.
        chrome.refresh(document: codeFile, selection: NSRange(location: 0, length: 0))

        // Step 2: equal-length edit relocating the line break, then an edit refresh
        // that only schedules the heavy recompute -- the cached index stays [0, 3].
        codeFile.content?.replaceCharacters(in: NSRange(location: 0, length: 5), with: "abcd\n")
        chrome.refreshForEdit(document: codeFile, selection: NSRange(location: 5, length: 0))

        // Step 3: a cursor move to offset 3 computes against the still-stale [0, 3].
        // The transiently-stale "2/2:4" is the tolerated staleness window; the bug
        // was that it never self-corrected.
        chrome.refreshForSelectionChange(document: codeFile, selection: NSRange(location: 3, length: 0))
        #expect(chrome.cursorPosition == "2/2:4")

        // Step 4: the debounced heavy recompute refreshes the cached index to
        // [0, 5]. The label must now settle on the correct line at rest.
        chrome.drainHeavyRecomputeForTesting(document: codeFile)
        #expect(chrome.cursorPosition == "1/2:4")
    }
}
