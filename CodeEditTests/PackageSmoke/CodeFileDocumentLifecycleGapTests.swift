//
//  CodeFileDocumentLifecycleGapTests.swift
//  CodeEditTests
//
//  Regression tests pinning the four HIGH-severity findings from
//  docs/active_plans/audits/document_lifecycle_audit.md (Findings 1-4). All four findings are
//  now closed. Each test asserts the fixed behavior directly; none is wrapped as an expected failure.
//  Do not weaken or remove the pinned assertions without updating the audit and the document
//  state contract at docs/active_plans/decisions/document_architecture_decision.md.
//

import AppKit
import Foundation
import CodeEditTextView
import Testing
@testable import CodeEdit

@Suite
struct CodeFileDocumentLifecycleGapTests {
    private func withTempDir(_ operation: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try operation(directory)
    }

    @MainActor
    private func withTempDirAsync(_ operation: (URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await operation(directory)
    }

    // Finding 1 (closed): undo/redo now clears and restores the document's dirty flag.
    //
    // The document owns change tracking: CodeFileView reports each mutation through
    // CodeFileDocument.recordEdit(_:replacedRange:newLength:) with how it reached the buffer
    // (forward edit, undo, or redo), and the document maps that to the matching NSDocument
    // change-count transition (.changeDone / .changeUndone / .changeRedone). This test drives
    // the same document API the view now uses, replacing the old sequence that mirrored the
    // bug by calling updateChangeCount(.changeDone) unconditionally on every change.
    @Test
    @MainActor
    func undoToSavedContentClearsDirtyFlag() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "undo_dirty.swift")
            let originalText = "let value = 1\n"
            let editedText = "let value = 2\n"
            let replacedRange = NSRange(location: 0, length: (originalText as NSString).length)
            try originalText.write(to: sourceURL, atomically: true, encoding: .utf8)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.source-code"
            )
            #expect(codeFile.isDocumentEdited == false)

            // Forward edit dirties the document.
            codeFile.content?.mutableString.setString(editedText)
            codeFile.recordEdit(
                .edit,
                replacedRange: replacedRange,
                newLength: (editedText as NSString).length
            )
            #expect(codeFile.isDocumentEdited == true)

            // Undo back to byte-identical saved content clears the dirty flag.
            codeFile.content?.mutableString.setString(originalText)
            codeFile.recordEdit(
                .undo,
                replacedRange: NSRange(location: 0, length: (editedText as NSString).length),
                newLength: (originalText as NSString).length
            )
            #expect(codeFile.isDocumentEdited == false)

            // Redo away from the saved content sets the dirty flag again.
            codeFile.content?.mutableString.setString(editedText)
            codeFile.recordEdit(
                .redo,
                replacedRange: replacedRange,
                newLength: (editedText as NSString).length
            )
            #expect(codeFile.isDocumentEdited == true)
        }
    }

    // Finding 2 (closed): an external change while the document has unsaved edits now
    // surfaces a conflict instead of being silently dropped.
    //
    // presentedItemDidChange routes a dirty + decodable external change to the keep-mine-or-reload
    // conflict: it acknowledges the observed on-disk version by advancing fileModificationDate to
    // the new mtime (so the same change is not re-prompted) and sets pendingExternalChange, which
    // the editor window renders as a SwiftUI alert. The buffer is left untouched until the user
    // chooses. fileModificationDate advancing to the on-disk mtime is the reachable,
    // package-testable proxy for "the conflict was surfaced"; it stayed stale in the baseline
    // because the old guard fell straight through when isDocumentEdited was true.
    @Test
    @MainActor
    func externalChangeWithUnsavedEditsSurfacesConflict() async throws {
        try await withTempDirAsync { dir in
            let sourceURL = dir.appending(path: "conflict.swift")
            let originalText = "let value = 1\n"
            try originalText.write(to: sourceURL, atomically: true, encoding: .utf8)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.source-code"
            )
            codeFile.content?.mutableString.setString("let value = 2 // unsaved edit\n")
            codeFile.updateChangeCount(.changeDone)
            #expect(codeFile.isDocumentEdited == true)

            // An external writer rewrites the backing file while the document is dirty.
            try "let value = 3 // external edit\n".write(to: sourceURL, atomically: true, encoding: .utf8)

            codeFile.presentedItemDidChange()
            // presentedItemDidChange dispatches its work in a Task { @MainActor ... }; yield long
            // enough for that task to run before inspecting the result.
            try await Task.sleep(nanoseconds: 200_000_000)

            let onDiskModificationDate = try FileManager.default.attributesOfItem(
                atPath: sourceURL.path
            )[.modificationDate] as? Date

            // The dirty buffer is kept as-is; the conflict is surfaced, not silently overwritten.
            #expect(codeFile.content?.string == "let value = 2 // unsaved edit\n")
            #expect(codeFile.pendingExternalChange == .reloadConflict)
            // The observed on-disk version is acknowledged, proving the conflict was surfaced
            // rather than silently dropped and leaving the date stale.
            #expect(codeFile.fileModificationDate == onDiskModificationDate)
        }
    }

    // Finding 3 (closed): a reload that cannot decode the new file contents surfaces an
    // error and leaves the in-memory document untouched, instead of advancing the modification
    // date behind stale text via a swallowed `try?`.
    //
    // The clean-document reload path now classifies the external bytes before touching the buffer:
    // an undecodable change surfaces the .undecodable alert with the buffer untouched, and
    // fileModificationDate is advanced only after a decodable reload actually succeeds. The date
    // staying at its pre-reload value on an undecodable external change is the reachable,
    // package-testable proxy for "an error was surfaced rather than silently swallowed."
    @Test
    @MainActor
    func undecodableExternalChangeSurfacesError() async throws {
        try await withTempDirAsync { dir in
            let sourceURL = dir.appending(path: "undecodable_reload.txt")
            let originalText = "Caf\u{E9} r\u{E9}sum\u{E9}\n"
            try originalText.write(to: sourceURL, atomically: true, encoding: .utf8)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.plain-text"
            )
            #expect(codeFile.isDocumentEdited == false)
            let storedModificationDateBeforeReload = codeFile.fileModificationDate

            // Rewrite the backing file with bytes that fail every supported decode (all five are
            // undefined in Windows-1252 and invalid UTF-8/UTF-16), while the document is clean.
            let undecodableBytes = Data([0x81, 0x8D, 0x8F, 0x90, 0x9D])
            try undecodableBytes.write(to: sourceURL)

            codeFile.presentedItemDidChange()
            try await Task.sleep(nanoseconds: 200_000_000)

            // The in-memory buffer must stay untouched.
            #expect(codeFile.content?.string == originalText)

            // The reload failed to decode, so the document must not advance its modification
            // date behind the stale text -- it never claims to be caught up with disk.
            #expect(codeFile.fileModificationDate == storedModificationDateBeforeReload)
        }
    }

    // Conflict-resolution regression: resolving a keep-mine-or-reload conflict with
    // "Reload from Disk" must not mark the document clean if the reload itself fails.
    //
    // resolveExternalChangeConflict called `try? self.read(...)` and then updateChangeCount(
    // .changeCleared) unconditionally. If the file changed again between the prompt and the click
    // (or its new bytes no longer decode), the swallowed read left the user's kept edits in the
    // buffer while the dirty flag was cleared -- a silent data-loss bug, since the next window
    // close would offer no save. The fix branches on the throw: a failed reload keeps
    // isDocumentEdited true and surfaces the error instead of clearing the flag.
    @Test
    @MainActor
    func reloadChoiceWithFailedReadKeepsEditsAndSurfacesError() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "reload_choice_fail.txt")
            let originalText = "let value = 1\n"
            try originalText.write(to: sourceURL, atomically: true, encoding: .utf8)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.plain-text"
            )

            // Dirty the document with unsaved edits.
            let editedText = "let value = 2 // unsaved edit\n"
            codeFile.content?.mutableString.setString(editedText)
            codeFile.updateChangeCount(.changeDone)
            #expect(codeFile.isDocumentEdited == true)

            // The on-disk file changes again to undecodable bytes before the user clicks
            // "Reload from Disk", so the reload read fails.
            let undecodableBytes = Data([0x81, 0x8D, 0x8F, 0x90, 0x9D])
            try undecodableBytes.write(to: sourceURL)

            codeFile.resolveExternalChangeConflict(reloadFromDisk: true)

            // The failed reload must keep the kept edits and the dirty flag, and surface an
            // error rather than silently marking the document clean over unsaved content.
            #expect(codeFile.content?.string == editedText)
            #expect(codeFile.isDocumentEdited == true)
            #expect(codeFile.pendingExternalChange == .undecodable)
        }
    }

    // Finding 4 (closed): an external reload resets the editor's undo stack.
    //
    // Wires a real TextView + CEUndoManager to the document's shared NSTextStorage, mirroring the
    // live wiring, and registers the same reset the production editor does: the document
    // broadcasts .fullInvalidation from its in-place reload path, and the editor layer that owns
    // the undo manager clears the now-stale stack in response (CodeFileView's reload observer). A
    // pre-reload edit registers an undo operation against pre-reload offsets; after the reload,
    // undo must be a clean no-op rather than a replay against mismatched content.
    @Test
    @MainActor
    func externalReloadInvalidatesStaleUndoOperations() throws {
        try withTempDir { dir in
            let sourceURL = dir.appending(path: "reload.swift")
            let originalText = "let value = 1\n"
            try originalText.write(to: sourceURL, atomically: true, encoding: .utf8)

            let codeFile = try CodeFileDocument(
                for: sourceURL,
                withContentsOf: sourceURL,
                ofType: "public.source-code"
            )
            guard let storage = codeFile.content else {
                Issue.record("codeFile.content unexpectedly nil after initial load")
                return
            }

            let textView = TextView(string: storage.string)
            textView.setTextStorage(storage)
            let undoManager = CEUndoManager()
            textView.setUndoManager(undoManager)

            // Mirror the production wiring (CodeFileView's reload observer): the document
            // broadcasts .fullInvalidation from its in-place reload path, and the editor
            // layer that owns the undo manager resets the now-stale stack in response.
            codeFile.addEditObserver { [weak undoManager] change in
                guard case .fullInvalidation = change else { return }
                undoManager?.clearStack()
            }

            // Pre-reload edit: insert a short prefix at offset 0. The stale undo operation this
            // registers (remove the first 3 characters) stays in-bounds against any reasonably
            // sized reload target below, so this test demonstrates buffer corruption rather than
            // an out-of-range crash -- a real out-of-range replace (offset past the reloaded
            // text's new length) instead raises an uncaught NSException that terminates the whole
            // test process, which Swift Testing has no way to pin as a known issue.
            textView.replaceCharacters(in: NSRange(location: 0, length: 0), with: "PRE")
            #expect(undoManager.canUndo)

            // External change: rewrite the backing file, then reload through the exact path
            // presentedItemDidChange uses (`self.read(from: fileURL, ofType: fileType)`).
            let reloadedText = "let value = 99\n"
            try reloadedText.write(to: sourceURL, atomically: true, encoding: .utf8)
            try codeFile.read(from: sourceURL, ofType: "public.source-code")
            #expect(storage.string == reloadedText)

            // The reload cleared the undo stack, so invoking undo now is a clean no-op and
            // leaves the reloaded content untouched rather than replaying a stale operation.
            #expect(undoManager.canUndo == false)
            undoManager.undo()

            #expect(storage.string == reloadedText)
        }
    }
}
