//
//  PlainEditorTextCleanerTests.swift
//  CodeEditTests
//
//  Created by Codex on 2026-07-07.
//

import Testing
@testable import CodeEdit

@Suite
struct PlainEditorTextCleanerTests {
    @Test
    func trimsTrailingSpaces() {
        let input = "line one   \nline two"
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\nline two")
    }

    @Test
    func trimsTrailingTabs() {
        let input = "line one\t\t\nline two"
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\nline two")
    }

    @Test
    func trimsMixedTrailingSpacesAndTabs() {
        let input = "line one \t \nline two\t  "
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\nline two")
    }

    @Test
    func preservesCarriageReturnLineFeedEndings() {
        let input = "line one  \r\nline two\t\r\n"
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\r\nline two\r\n")
    }

    @Test
    func handlesEmptyInput() {
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: "")

        #expect(output.isEmpty)
    }

    @Test
    func preservesLoneCarriageReturnEndings() {
        let input = "line one \t\rline two  \r"
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\rline two\r")
    }

    @Test
    func trimsTrailingWhitespaceOnFinalLineWithoutNewline() {
        let input = "line one\nline two\t  "
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\nline two")
    }
}
