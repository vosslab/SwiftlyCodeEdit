//
//  EditedRangeContractTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-10.
//
//  Entry-criterion sufficiency check: pins the Clean Text case of the
//  edited-range contract (docs/active_plans/decisions/document_architecture_decision.md).
//  Clean Text applies through `TextView.replaceCharacters`, the same mutation API
//  typing, paste, undo, and redo use, so it fires `didReplaceContentsIn` and
//  broadcasts through the normal per-mutation path -- it does not bypass the
//  notification by mutating `NSTextStorage` directly. This pins the exact shape:
//  a bounded `.range` covering the whole pre-edit buffer, not `.fullInvalidation`
//  (only the external-reload path broadcasts that case; see
//  CodeFileDocument.swift's `read(from:ofType:)`).
//

@testable import CodeEdit
import AppKit
import Foundation
import CodeEditTextView
import Testing

@MainActor
@Suite
struct EditedRangeContractTests {
    // Forwards `didReplaceContentsIn` into `recordEdit`, mirroring
    // `PlainTextEditorView.Coordinator`'s wiring so this test drives the same
    // notification path production code uses, not a shortcut around it.
    @MainActor
    private final class RecordingDelegate: NSObject, @preconcurrency TextViewDelegate {
        let codeFile: CodeFileDocument
        init(codeFile: CodeFileDocument) {
            self.codeFile = codeFile
        }
        func textView(_ textView: TextView, didReplaceContentsIn range: NSRange, with string: String) {
            codeFile.recordEdit(.edit, replacedRange: range, newLength: (string as NSString).length)
        }
    }

    @MainActor
    private final class EditChangeRecorder {
        var changes: [CodeFileDocument.EditedTextChange] = []
    }

    private func withTempDir(_ operation: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try operation(directory)
    }

    // Clean Text (trim trailing whitespace) applies through the same
    // `TextView.replaceCharacters` mutation API as typing, paste, undo, and redo. This
    // pins that it broadcasts a bounded `.range` covering the whole pre-edit buffer --
    // not `.fullInvalidation` -- so an edited-range consumer (bounded rehighlighter, incremental
    // status bar) receives a usable, non-empty payload for this case rather than
    // silence.
    @Test
    func cleanTextBroadcastsBoundedRangeNotFullInvalidation() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "clean_text_contract.swift")
            let originalText = "let value = 1   \nlet other = 2\t\n"
            try originalText.write(to: sourceURL, atomically: true, encoding: .utf8)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.source-code"
            )

            let textView = TextView(string: "")
            textView.setTextStorage(NSTextStorage(string: originalText))
            textView.setUndoManager(CEUndoManager())
            let delegate = RecordingDelegate(codeFile: codeFile)
            textView.delegate = delegate

            let recorder = EditChangeRecorder()
            codeFile.addEditObserver { recorder.changes.append($0) }

            let router = EditorCommandRouter()
            router.register(textView: textView, for: ObjectIdentifier(textView))
            #expect(router.cleanText() == true)

            let expectedCleaned = "let value = 1\nlet other = 2\n"
            #expect(textView.string == expectedCleaned)

            // Verdict: Clean Text is covered by the same `.range` case as typing, paste,
            // undo, and redo -- a bounded range spanning the whole pre-edit buffer, with
            // `newLength` matching the cleaned text. It is not `.fullInvalidation`,
            // despite the doc comment on `EditedTextChange.fullInvalidation` naming
            // "Clean Text" alongside reload; only the external-reload path broadcasts
            // that case.
            #expect(recorder.changes == [
                .range(
                    replacedRange: NSRange(location: 0, length: (originalText as NSString).length),
                    newLength: (expectedCleaned as NSString).length
                )
            ])
        }
    }
}
