import Foundation
import Testing
@testable import CodeEdit

@Suite
struct CodeFileDocumentLifecycleTests {
    private func withTempDir(_ operation: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try operation(directory)
    }

    @Test
    @MainActor
    func lifecyclePersistsSyntheticEdit() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "sample.swift")
            let savedURL = dir.appending(path: "saved.swift")
            let originalText = "func sample() {\n    print(\"hello\")\n}\n"
            let editedText = "func sample() {\n    print(\"hello, world\")\n}\n"

            try originalText.write(to: sourceURL, atomically: true, encoding: .utf8)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.source-code"
            )

            #expect(codeFile.content?.string == originalText)

            codeFile.content?.mutableString.setString(editedText)
            codeFile.updateChangeCount(.changeDone)
            codeFile.sourceEncoding = .utf8
            try codeFile.write(to: savedURL, ofType: "public.source-code")

            let reopened = try CodeFileDocument(
                for: savedURL,
                withContentsOf: savedURL,
                ofType: "public.source-code"
            )

            #expect(reopened.content?.string == editedText)
            #expect(reopened.sourceEncoding == .utf8)
        }
    }

    // A Latin-1 (ISO-8859-1) file must open as real decoded text with a real encoding
    // recorded, not as a silent blank window. The high bytes are invalid standalone UTF-8
    // sequences, so decoding falls through to the single-byte path.
    @Test
    @MainActor
    func latin1FileDecodesToRealText() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "latin1.txt")
            let expectedText = "Caf\u{E9} r\u{E9}sum\u{E9} for Se\u{F1}or\n"
            let latin1Bytes = expectedText.data(using: .isoLatin1)
            #expect(latin1Bytes != nil)
            try latin1Bytes?.write(to: sourceURL)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.plain-text"
            )

            #expect(codeFile.content?.string == expectedText)
            #expect(codeFile.sourceEncoding == .latin1)
            // Status must reflect the real encoding, never the old "UTF-8" lie.
            #expect(PlainEditorStatusReporter.encodingLabel(codeFile.sourceEncoding) == "ISO Latin-1")
        }
    }

    // A short Latin-1 file that Foundation's heuristic misjudges as UTF-8 must still open as
    // real text via the deterministic Windows-1252 fallback, never as a silent blank window.
    @Test
    @MainActor
    func shortHighByteFileDecodesViaFallback() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "short.txt")
            let expectedText = "Caf\u{E9}\n"
            let bytes = Data([0x43, 0x61, 0x66, 0xE9, 0x0A])
            try bytes.write(to: sourceURL)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.plain-text"
            )

            #expect(codeFile.content?.string == expectedText)
            #expect(codeFile.sourceEncoding != nil)
        }
    }

    // A Windows-1252 file with printable 0x80-0x9F bytes (smart quotes) must decode as that
    // text, proving Windows-1252 is a supported decode path distinct from Latin-1.
    @Test
    @MainActor
    func windows1252FileDecodesToRealText() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "cp1252.txt")
            // 0x93 and 0x94 are left/right double quotation marks in Windows-1252.
            let expectedText = "\u{201C}Hi\u{201D}\n"
            let cp1252Bytes = Data([0x93, 0x48, 0x69, 0x94, 0x0A])
            try cp1252Bytes.write(to: sourceURL)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.plain-text"
            )

            #expect(codeFile.content?.string == expectedText)
            #expect(codeFile.sourceEncoding == .windows1252)
        }
    }

    // A file matching no supported decoding must throw a real error and open nothing, rather
    // than returning silently. These five bytes are all undefined in Windows-1252 and invalid
    // UTF-8/UTF-16, so every supported decode fails.
    @Test
    @MainActor
    func undecodableFileThrowsInsteadOfBlankWindow() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "undecodable.bin")
            let undecodableBytes = Data([0x81, 0x8D, 0x8F, 0x90, 0x9D])
            try undecodableBytes.write(to: sourceURL)

            #expect(throws: CodeFileError.self) {
                _ = try CodeFileDocument(
                    for: sourceURL,
                    withContentsOf: sourceURL,
                    ofType: "public.plain-text"
                )
            }
        }
    }

    // Encoding fix (recorded in docs/active_plans/active/scope_closure_plan.md,
    // Update 2026-07-09): a BOM-less UTF-16 little-endian file must decode as real text with no
    // embedded NULs, not the silent content-corruption previously pinned here (see git history for
    // the original `bomlessUTF16LittleEndianSilentlyMisdecodesAsUTF8` bug-contract test this
    // replaces). `decode(data:)` now runs a plausibility pre-check before Foundation's heuristic,
    // recognizing the interleaved-0x00 pattern and decoding as UTF-16LE directly.
    @Test
    @MainActor
    func bomlessUTF16LittleEndianDecodesCorrectly() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "bomless_le.txt")
            let intendedText = "Hi\n"
            let bomlessLEBytes = intendedText.data(using: .utf16LittleEndian)
            #expect(bomlessLEBytes != nil)
            try bomlessLEBytes?.write(to: sourceURL)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.plain-text"
            )

            #expect(codeFile.content?.string == intendedText)
            #expect(codeFile.sourceEncoding == .utf16LE)
            #expect(PlainEditorStatusReporter.encodingLabel(codeFile.sourceEncoding) == "UTF-16 LE")
        }
    }

    // Encoding fix: same probe for BOM-less UTF-16 big-endian, mirroring the little-endian case above.
    @Test
    @MainActor
    func bomlessUTF16BigEndianDecodesCorrectly() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "bomless_be.txt")
            let intendedText = "Hi\n"
            let bomlessBEBytes = intendedText.data(using: .utf16BigEndian)
            #expect(bomlessBEBytes != nil)
            try bomlessBEBytes?.write(to: sourceURL)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.plain-text"
            )

            #expect(codeFile.content?.string == intendedText)
            #expect(codeFile.sourceEncoding == .utf16BE)
            #expect(PlainEditorStatusReporter.encodingLabel(codeFile.sourceEncoding) == "UTF-16 BE")
        }
    }

    // A UTF-8 file with an explicit byte-order mark must decode as UTF-8 with the BOM stripped
    // from the resulting text, matching Foundation's standard UTF-8-with-BOM handling.
    @Test
    @MainActor
    func utf8WithBOMDecodesWithBOMStripped() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "bom_utf8.txt")
            let expectedText = "Hi\n"
            var bomBytes = Data([0xEF, 0xBB, 0xBF])
            bomBytes.append(expectedText.data(using: .utf8)!)
            try bomBytes.write(to: sourceURL)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.plain-text"
            )

            // Pinned contract: the BOM is stripped from decoded content, not preserved as a
            // leading U+FEFF character.
            #expect(codeFile.content?.string == expectedText)
            #expect(codeFile.sourceEncoding == .utf8)
        }
    }

    // A lone Windows-1252-undefined byte (0x81) must fail every supported decode and raise the
    // real decode error, confirming the rejected-byte behavior recorded in the audit still holds for a
    // single-byte file, not just the five-byte combination in
    // ``undecodableFileThrowsInsteadOfBlankWindow``.
    @Test
    @MainActor
    func singleRejectedWindows1252ByteThrows() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "rejected_byte.bin")
            let rejectedByte = Data([0x81])
            try rejectedByte.write(to: sourceURL)

            #expect(throws: CodeFileError.self) {
                _ = try CodeFileDocument(
                    for: sourceURL,
                    withContentsOf: sourceURL,
                    ofType: "public.plain-text"
                )
            }
        }
    }

    // Windows-1252 smart-quote bytes (0x93/0x94) decode via the fallback, with the encoding
    // reported as windows1252 (not latin1), confirming the fallback path is exercised for
    // printable 0x80-0x9F bytes specifically.
    @Test
    @MainActor
    func windows1252SmartQuotesReportWindows1252Encoding() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "smart_quotes.txt")
            let expectedText = "\u{201C}Yo\u{201D}\n"
            let smartQuoteBytes = Data([0x93, 0x59, 0x6F, 0x94, 0x0A])
            try smartQuoteBytes.write(to: sourceURL)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.plain-text"
            )

            #expect(codeFile.content?.string == expectedText)
            #expect(codeFile.sourceEncoding == .windows1252)
            #expect(PlainEditorStatusReporter.encodingLabel(codeFile.sourceEncoding) != "ISO Latin-1")
        }
    }

    // Reload-direction encoding case: a file opened as UTF-8 that is rewritten on disk in a
    // different but still-supported encoding (Latin-1) reloads to the new decoded text with the
    // re-detected encoding recorded. This exercises the successful clean-reload branch and the
    // encoding re-detection the reload path performs, the decode direction opposite the initial
    // open the rest of this matrix covers.
    @Test
    @MainActor
    func reloadRedetectsEncodingForDecodableExternalChange() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "reload_encoding.txt")
            let originalText = "plain ascii\n"
            try originalText.write(to: sourceURL, atomically: true, encoding: .utf8)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.plain-text"
            )
            #expect(codeFile.sourceEncoding == .utf8)

            // Rewrite the backing file in Latin-1 with high bytes that are invalid standalone
            // UTF-8, then reload through the same read path the external-change handler uses.
            let reloadedText = "Caf\u{E9} r\u{E9}sum\u{E9}\n"
            let latin1Bytes = reloadedText.data(using: .isoLatin1)
            #expect(latin1Bytes != nil)
            try latin1Bytes?.write(to: sourceURL)
            try codeFile.read(from: sourceURL, ofType: "public.plain-text")

            #expect(codeFile.content?.string == reloadedText)
            #expect(codeFile.sourceEncoding == .latin1)
        }
    }

    // A bounded edit broadcasts the explicit range case of the two-case
    // edited-range change notification (replaced range plus new length), so a range-bounded
    // consumer (rehighlighter/status) rescans only the edited region, never the whole buffer.
    @Test
    @MainActor
    func recordEditBroadcastsBoundedRangeChange() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "edited_range.swift")
            try "let value = 1\n".write(to: sourceURL, atomically: true, encoding: .utf8)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.source-code"
            )

            let recorder = EditChangeRecorder()
            codeFile.addEditObserver { recorder.changes.append($0) }

            codeFile.recordEdit(.edit, replacedRange: NSRange(location: 4, length: 5), newLength: 7)

            #expect(recorder.changes == [.range(replacedRange: NSRange(location: 4, length: 5), newLength: 7)])
        }
    }

    // An external reload replaces the whole buffer and broadcasts the explicit
    // full-invalidation case, distinct from a bounded range edit, so consumers rescan everything.
    @Test
    @MainActor
    func externalReloadBroadcastsFullInvalidation() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "reload_invalidation.swift")
            try "let value = 1\n".write(to: sourceURL, atomically: true, encoding: .utf8)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.source-code"
            )

            let recorder = EditChangeRecorder()
            codeFile.addEditObserver { recorder.changes.append($0) }

            // Rewrite the backing file and reload through the same read path the
            // external-change handler uses; the whole buffer is replaced.
            try "let value = 22\n".write(to: sourceURL, atomically: true, encoding: .utf8)
            try codeFile.read(from: sourceURL, ofType: "public.source-code")

            #expect(recorder.changes == [.fullInvalidation])
        }
    }
}

/// Collects broadcast ``CodeFileDocument/EditedTextChange`` values for assertion. A main-actor
/// reference type so the escaping observer closure records into shared state without capturing a
/// mutable local.
@MainActor
private final class EditChangeRecorder {
    var changes: [CodeFileDocument.EditedTextChange] = []
}
