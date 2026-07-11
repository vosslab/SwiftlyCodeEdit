import Foundation
import CodeEditLanguages

// Status-bar metric functions for the plain editor. Every text metric operates
// on `NSString` (the editor's live `NSTextStorage.mutableString` backing store)
// rather than bridging a fresh Swift `String` copy on each call, and scans the
// UTF-16 code units directly instead of allocating line/word arrays. This is the
// status-bar fix: the previous String-based passes (whole-document
// `components(separatedBy:)` splits plus a Unicode-grapheme word scan, run three
// times per keystroke) were the measured ~2 s per-keystroke floor. The heavier
// metrics (`wordCount`, `indentationLabel`, `lineEndingLabel`) run on a debounce
// off the keystroke hot path; only the cursor label and character count stay on
// the immediate path, so they are kept cheap here.
enum PlainEditorStatusReporter {
    // MARK: - Line counting (cursor label denominator and "N lines")

    /// The cursor position label `line/totalLines:column`.
    ///
    /// `totalLines` is passed in (the model caches it and refreshes it on the
    /// debounce) so a plain cursor move never rescans the whole document for the
    /// denominator. Only the numerator -- line breaks before the cursor -- and the
    /// column are computed here, both from bounded UTF-16 scans.
    static func cursorLabel(text: NSString, selection: NSRange, totalLines: Int) -> String {
        let cappedLocation = max(0, min(selection.location, text.length))
        let lineNumber = countLineBreaks(in: text, range: NSRange(location: 0, length: cappedLocation)) + 1
        // lineRange scans backward to the line start and forward to the line end;
        // it is bounded by the current line length, not the whole document.
        let lineRange = text.lineRange(for: NSRange(location: cappedLocation, length: 0))
        // Column in UTF-16 units from the line start. One-based to match editor
        // conventions ("column 1" is the first character on the line).
        let column = cappedLocation - lineRange.location + 1
        let label = "\(lineNumber)/\(max(1, totalLines)):\(column)"
        return label
    }

    /// The cursor position label `line/totalLines:column`, identical in output to
    /// `cursorLabel(text:selection:totalLines:)` above, but computing the
    /// numerator with a binary search into a caller-cached `lineStartIndex`
    /// (built by `lineStartIndex(in:)`, alongside `totalLines`, on the
    /// heavy-metrics recompute) instead of an O(cursor-offset) newline count.
    /// This is the immediate-path variant the status-bar fix calls on every
    /// keystroke; `lineStartIndex` may be up to one debounce cycle stale, the
    /// same staleness window `totalLines` already tolerates.
    static func cursorLabel(
        text: NSString,
        selection: NSRange,
        totalLines: Int,
        lineStartIndex: [Int]
    ) -> String {
        let cappedLocation = max(0, min(selection.location, text.length))
        let lineNumber = lineNumber(forOffset: cappedLocation, lineStartIndex: lineStartIndex)
        // lineRange scans backward to the line start and forward to the line end;
        // it is bounded by the current line length, not the whole document.
        let lineRange = text.lineRange(for: NSRange(location: cappedLocation, length: 0))
        // Column in UTF-16 units from the line start. One-based to match editor
        // conventions ("column 1" is the first character on the line).
        let column = cappedLocation - lineRange.location + 1
        let label = "\(lineNumber)/\(max(1, totalLines)):\(column)"
        return label
    }

    /// The total number of lines: line breaks plus one. A trailing newline yields
    /// the conventional extra empty line, and a CRLF pair counts as one break so a
    /// Windows-lineending file is not double counted.
    static func lineCount(in text: NSString) -> Int {
        let lines = countLineBreaks(in: text, range: NSRange(location: 0, length: text.length)) + 1
        return lines
    }

    /// An index of the UTF-16 offset where each line begins: `index[0]` is always
    /// `0`, and `index[k]` is the offset of the first UTF-16 unit of line `k + 1`.
    /// `index.count` equals `lineCount(in:)` for the same text, since each entry
    /// (the initial `0` plus one per line break) corresponds to exactly one line.
    ///
    /// This mirrors `countLineBreaks`'s CRLF-and-standalone-break detection (a
    /// CRLF pair is one break, matching `lineCount`), but records the running
    /// offset of each break instead of only a count, so `lineNumber(forOffset:
    /// lineStartIndex:)` can binary-search a cursor offset to a line number in
    /// O(log lines) instead of rescanning from the start of the document
    /// (this was the O(cursor-offset) `cursorLabel` numerator scan).
    static func lineStartIndex(in text: NSString) -> [Int] {
        var offsets = [0]
        var previousWasCarriageReturn = false
        var chunkStart = 0
        forEachChunk(in: text, whole: text.length) { buffer, chunkLength in
            var index = 0
            while index < chunkLength {
                let unit = buffer[index]
                // The offset immediately after this UTF-16 unit is where the next
                // line would start if this unit turns out to end the line.
                let nextLineStart = chunkStart + index + 1
                if previousWasCarriageReturn {
                    previousWasCarriageReturn = false
                    // A LF right after a CR is the tail of a CRLF pair: the line
                    // start recorded for the CR moves past this LF instead of a
                    // second entry being appended.
                    if unit == 0x0A {
                        offsets[offsets.count - 1] = nextLineStart
                        index += 1
                        continue
                    }
                }
                if unit == 0x0D {
                    offsets.append(nextLineStart)
                    previousWasCarriageReturn = true
                } else if isStandaloneLineBreak(unit) {
                    offsets.append(nextLineStart)
                }
                index += 1
            }
            chunkStart += chunkLength
        }
        return offsets
    }

    /// Binary-searches `lineStartIndex` for the 1-based line number containing
    /// `offset`: the greatest line whose recorded start is `<= offset`. `offset`
    /// is expected to already be capped to `[0, text.length]` by the caller.
    static func lineNumber(forOffset offset: Int, lineStartIndex: [Int]) -> Int {
        var low = 0
        var high = lineStartIndex.count - 1
        while low < high {
            // Round the midpoint up so `low` always advances, since the search
            // keeps the invariant lineStartIndex[low] <= offset.
            let mid = (low + high + 1) / 2
            if lineStartIndex[mid] <= offset {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low + 1
    }

    // MARK: - Word counting (debounced, off the keystroke hot path)

    /// The number of maximal runs of word characters (Unicode letters, digits, and
    /// the underscore), matching the identifier-oriented definition the status bar
    /// has always used (so `snake_case_name` counts as one word). Scanned over the
    /// UTF-16 code units with an ASCII fast path, since editor content is
    /// overwhelmingly ASCII source text.
    static func wordCount(in text: NSString) -> Int {
        let length = text.length
        guard length > 0 else {
            return 0
        }
        var count = 0
        var inWord = false
        forEachChunk(in: text, whole: length) { buffer, chunkLength in
            var index = 0
            while index < chunkLength {
                let isWord = isWordCharacter(buffer[index])
                if isWord && !inWord {
                    // A non-word to word transition starts a new word.
                    count += 1
                }
                inWord = isWord
                index += 1
            }
        }
        return count
    }

    // MARK: - Indentation and line ending (debounced, off the keystroke hot path)

    /// The dominant indentation style across the first 50 lines: tabs, a soft-tab
    /// width, or Unknown. Only the sampled prefix is read, so this never scans the
    /// whole document.
    static func indentationLabel(in text: NSString) -> String {
        let length = text.length
        var tabbedLines = 0
        var spaceWidthCounts: [Int: Int] = [:]
        var lineStart = 0
        var linesSampled = 0

        while lineStart < length && linesSampled < 50 {
            var lineEnd = 0
            var contentsEnd = 0
            text.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd,
                              for: NSRange(location: lineStart, length: 0))
            classifyIndentation(
                text,
                contentRange: NSRange(location: lineStart, length: contentsEnd - lineStart),
                tabbedLines: &tabbedLines,
                spaceWidthCounts: &spaceWidthCounts
            )
            linesSampled += 1
            // getLineStart returns the next line's start; when there is no trailing
            // newline it equals length, so the loop condition ends the scan.
            if lineEnd <= lineStart {
                break
            }
            lineStart = lineEnd
        }

        if tabbedLines > spaceWidthCounts.values.reduce(0, +) {
            return "Tabs"
        }
        if let best = spaceWidthCounts.max(by: { $0.value < $1.value })?.key {
            return "Soft Tabs: \(best)"
        }
        return "Unknown"
    }

    /// The line-ending style, detected in the same precedence order as before:
    /// CRLF, then a lone CR, then LF. `range(of:)` is a C-level scan on the backing
    /// store rather than a Swift `contains` over a bridged copy.
    static func lineEndingLabel(in text: NSString) -> String {
        if text.range(of: "\r\n").location != NSNotFound {
            return "CRLF"
        }
        if text.range(of: "\r").location != NSNotFound {
            return "CR"
        }
        if text.range(of: "\n").location != NSNotFound {
            return "LF"
        }
        return "Unknown"
    }

    // MARK: - Encoding and language (unchanged, O(1))

    static func encodingLabel(_ encoding: FileEncoding?) -> String {
        // A nil source encoding means no supported decoding was applied. Report "Unknown" here
        // so the status bar never claims an encoding the file was not actually read with.
        guard let encoding else {
            return "Unknown"
        }

        switch encoding {
        case .utf8:
            return "UTF-8"
        case .utf16BE:
            return "UTF-16 BE"
        case .utf16LE:
            return "UTF-16 LE"
        case .windows1252:
            return "Windows-1252"
        case .latin1:
            return "ISO Latin-1"
        }
    }

    static func languageLabel(_ language: CodeLanguage) -> String {
        switch language.id {
        case .markdown, .markdownInline:
            return "Markdown"
        case .json:
            return "JSON"
        case .yaml:
            return "YAML"
        case .swift:
            return "Swift"
        case .plainText:
            return "Plain Text"
        default:
            return language.tsName.capitalized
        }
    }

    // MARK: - UTF-16 scanning primitives

    // Reads `range` from the backing store one bounded chunk at a time and hands
    // each chunk to `body`, so a whole-document scan never allocates a buffer the
    // size of the document. The chunk is a plain UTF-16 buffer, so `body` runs at
    // C-array speed with no per-character Objective-C dispatch.
    private static let scanChunkSize = 8192

    private static func forEachChunk(
        in text: NSString,
        range: NSRange,
        _ body: (_ buffer: [unichar], _ chunkLength: Int) -> Void
    ) {
        guard range.length > 0 else {
            return
        }
        var buffer = [unichar](repeating: 0, count: min(scanChunkSize, range.length))
        var offset = 0
        while offset < range.length {
            let chunkLength = min(scanChunkSize, range.length - offset)
            text.getCharacters(&buffer, range: NSRange(location: range.location + offset, length: chunkLength))
            body(buffer, chunkLength)
            offset += chunkLength
        }
    }

    private static func forEachChunk(
        in text: NSString,
        whole length: Int,
        _ body: (_ buffer: [unichar], _ chunkLength: Int) -> Void
    ) {
        forEachChunk(in: text, range: NSRange(location: 0, length: length), body)
    }

    // Counts line breaks in `range`, treating a CRLF pair as a single break so a
    // Windows-lineending document is not double counted. Handles a CRLF split
    // across a chunk boundary via the carried `previousWasCarriageReturn` flag.
    private static func countLineBreaks(in text: NSString, range: NSRange) -> Int {
        var count = 0
        var previousWasCarriageReturn = false
        forEachChunk(in: text, range: range) { buffer, chunkLength in
            var index = 0
            while index < chunkLength {
                let unit = buffer[index]
                if previousWasCarriageReturn {
                    previousWasCarriageReturn = false
                    // A LF right after a CR is the tail of a CRLF already counted.
                    if unit == 0x0A {
                        index += 1
                        continue
                    }
                }
                if unit == 0x0D {
                    count += 1
                    previousWasCarriageReturn = true
                } else if isStandaloneLineBreak(unit) {
                    count += 1
                }
                index += 1
            }
        }
        return count
    }

    // Leading-whitespace classification for a single line's content range.
    private static func classifyIndentation(
        _ text: NSString,
        contentRange: NSRange,
        tabbedLines: inout Int,
        spaceWidthCounts: inout [Int: Int]
    ) {
        guard contentRange.length > 0 else {
            return
        }
        let first = text.character(at: contentRange.location)
        if first == 0x09 {
            tabbedLines += 1
            return
        }
        if first == 0x20 {
            var spaces = 0
            var index = contentRange.location
            let end = contentRange.location + contentRange.length
            while index < end && text.character(at: index) == 0x20 {
                spaces += 1
                index += 1
            }
            if spaces > 0 {
                spaceWidthCounts[spaces, default: 0] += 1
            }
        }
    }

    // Line-break code units other than CR (which needs CRLF lookahead handling):
    // LF, vertical tab, form feed, NEL, line separator, paragraph separator. This
    // is the same set Foundation's `.newlines` covers, so the count matches the
    // prior `components(separatedBy: .newlines)` intent for these characters.
    private static func isStandaloneLineBreak(_ unit: unichar) -> Bool {
        switch unit {
        case 0x0A, 0x0B, 0x0C, 0x85, 0x2028, 0x2029:
            return true
        default:
            return false
        }
    }

    // ASCII word-character lookup, sized to the ASCII range. Non-ASCII units fall
    // back to the Unicode word set. Source text is overwhelmingly ASCII, so the
    // table lookup carries the scan.
    private static let asciiWordFlags: [Bool] = {
        var flags = [Bool](repeating: false, count: 128)
        for code in 0..<128 {
            let scalar = UnicodeScalar(UInt8(code))
            let character = Character(scalar)
            flags[code] = character.isLetter || character.isNumber || character == "_"
        }
        return flags
    }()

    // Unicode word set for the rare non-ASCII unit: letters, digits, underscore.
    // The value-type CharacterSet is Sendable, so it is safe as a static constant.
    private static let unicodeWordCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

    private static func isWordCharacter(_ unit: unichar) -> Bool {
        if unit < 128 {
            return asciiWordFlags[Int(unit)]
        }
        // A surrogate half is not a word character; a valid BMP scalar maps directly.
        guard let scalar = Unicode.Scalar(unit) else {
            return false
        }
        return unicodeWordCharacters.contains(scalar)
    }
}
