//
//  CodeFileDocument.swift
//  CodeEditModules/CodeFile
//
//  Created by Rehatbir Singh on 12/03/2022.
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CodeEditLanguages
import OSLog

enum CodeFileError: Error, LocalizedError {
    case failedToDecode
    case failedToEncode
    case fileTypeError

    /// Human-readable text surfaced by the NSDocument error alert. `read(from:ofType:)`
    /// throws ``failedToDecode`` when a file matches none of ``FileEncoding``'s supported
    /// decodings, so the message explains that outcome directly to the user.
    var errorDescription: String? {
        switch self {
        case .failedToDecode:
            return "The file could not be opened because its text encoding is not supported."
        case .failedToEncode:
            return "The file could not be saved because its text could not be encoded."
        case .fileTypeError:
            return "The file type is not supported."
        }
    }
}

@objc(CodeFileDocument)
final class CodeFileDocument: NSDocument, ObservableObject {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "CodeFileDocument")

    /// Sent when the document is opened. The document will be sent in the notification's object.
    static let didOpenNotification = Notification.Name(rawValue: "CodeFileDocument.didOpen")
    /// Sent when the document is closed. The document's `fileURL` will be sent in the notification's object.
    static let didCloseNotification = Notification.Name(rawValue: "CodeFileDocument.didClose")

    /// The text content of the document, stored as a text storage
    ///
    /// This is intentionally not a `@Published` variable. If it were published, SwiftUI would do a string
    /// compare each time the contents are updated, which could cause a hang on each keystroke if the file is large
    /// enough.
    ///
    var content: NSTextStorage?

    /// The string encoding of the original file. Used to save the file back to the encoding it was loaded from.
    var sourceEncoding: FileEncoding?

    /// Used to override detected languages.
    @Published var language: CodeLanguage?

    /// A pending external-change conflict the editor window surfaces to the user.
    /// `CodeFileView` observes this (the document is an `ObservableObject`) and
    /// presents a SwiftUI alert while it is non-nil. It is set by
    /// ``presentedItemDidChange()`` for the three matrix rows that need the user's
    /// attention -- a dirty document whose file changed on disk (keep-mine vs
    /// reload), an undecodable external change, and a deleted or moved file -- and
    /// cleared when the user resolves or dismisses it. A clean, decodable external
    /// change reloads silently and never sets this. See the external-change matrix
    /// in docs/active_plans/decisions/document_architecture_decision.md.
    @Published var pendingExternalChange: ExternalChangePrompt?

    /// The external-change situations the editor asks the user about. The clean +
    /// decodable case is intentionally absent: it reloads silently.
    enum ExternalChangePrompt: Sendable, Equatable {
        /// Dirty document, decodable change on disk: keep my edits, or reload.
        case reloadConflict
        /// The on-disk bytes no longer decode: error alert, buffer untouched.
        case undecodable
        /// The backing file was deleted or moved: alert, document needs Save As.
        case fileDeleted
    }

    /// The type of data this file document contains.
    ///
    /// If its text content is not nil, a `text` UTType is returned.
    ///
    /// - Note: The UTType doesn't necessarily mean the file extension, it can be the MIME
    /// type or any other form of data representation.
    var utType: UTType? {
        if content != nil {
            return .text
        }

        guard let fileType, let type = UTType(fileType) else {
            return nil
        }

        return type
    }

    /// A lock that ensures autosave scheduling happens correctly.
    private var autosaveTimerLock: NSLock = NSLock()
    /// Timer used to schedule autosave intervals.
    private var autosaveTimer: Timer?

    // MARK: - Text change tracking

    /// How a text mutation reached ``content``, so the document maps each to the
    /// matching `NSDocument` change-count transition. Forward edits dirty the
    /// document; an undo steps the change count back toward the saved state; a redo
    /// steps it away again. This is the distinction today's code missed by calling
    /// `.changeDone` unconditionally on every text change (document state contract,
    /// dirty flag semantics).
    enum EditKind: Sendable {
        case edit
        case undo
        case redo
    }

    /// The two-case edited-range change payload broadcast on every text change, so a
    /// consumer can bound its work to the edited region instead of rescanning the
    /// whole document. The case is explicit -- a consumer never infers it from range
    /// heuristics -- so the bounded rehighlighter and the incremental status bar each
    /// handle exactly two shapes. `Sendable` per the Resolved decisions state model.
    enum EditedTextChange: Sendable, Equatable {
        /// A bounded edit: the characters in `replacedRange` (pre-edit character
        /// coordinates) became `newLength` characters. Covers typing, paste, undo,
        /// redo, and find-replace.
        case range(replacedRange: NSRange, newLength: Int)
        /// The whole buffer was replaced out-of-band by a direct storage mutation
        /// (external reload; any future direct-storage write); a consumer rescans
        /// the entire document. Clean Text is not a producer -- it edits through
        /// the normal replaceCharacters path and so broadcasts a full-buffer range.
        case fullInvalidation
    }

    /// Handlers notified with the two-case ``EditedTextChange`` on every text change.
    /// The bounded rehighlighter and incremental status bar subscribe here rather
    /// than observing raw `NSTextStorage` edits, so they receive the explicit case.
    /// Edit consumers drive main-actor UI, so handlers are main-actor isolated.
    private var editObservers: [@MainActor (EditedTextChange) -> Void] = []

    /// Subscribes `handler` to this document's edited-range change notifications.
    @MainActor
    func addEditObserver(_ handler: @escaping @MainActor (EditedTextChange) -> Void) {
        editObservers.append(handler)
    }

    /// Delivers an edited-range change to every subscribed observer.
    @MainActor
    private func broadcast(_ change: EditedTextChange) {
        for handler in editObservers {
            handler(change)
        }
    }

    /// Records a mutation the editor made to ``content`` and updates the dirty flag.
    ///
    /// Views report edits here instead of calling ``updateChangeCount`` directly, so
    /// the document -- not the view -- owns change tracking (document state contract).
    /// An undo back to the saved text clears ``isDocumentEdited``; a redo away from it
    /// sets the flag again. Also broadcasts the bounded ``EditedTextChange/range(replacedRange:newLength:)``
    /// so range-bounded consumers can rehighlight or restat just the edited region.
    /// - Parameters:
    ///   - kind: How the mutation reached the buffer (forward edit, undo, or redo).
    ///   - replacedRange: The pre-edit character range that was replaced.
    ///   - newLength: The character length of the replacement text.
    @MainActor
    func recordEdit(_ kind: EditKind, replacedRange: NSRange, newLength: Int) {
        switch kind {
        case .edit:
            updateChangeCount(.changeDone)
        case .undo:
            updateChangeCount(.changeUndone)
        case .redo:
            updateChangeCount(.changeRedone)
        }
        broadcast(.range(replacedRange: replacedRange, newLength: newLength))
    }

    // MARK: - NSDocument

    override static var autosavesInPlace: Bool {
        true
    }

    override var autosavingFileType: String? {
        fileType
    }

    @MainActor
    override func makeWindowControllers() {
        // Window construction (NSWindow, NSWindowController, NSHostingController) is
        // owned by the single sanctioned document-layer bridge so this file stays the
        // document model. See CodeFileDocumentBridge.swift and
        // docs/active_plans/decisions/document_architecture_decision.md.
        CodeFileWindowBridge.installWindowController(for: self)
    }

    // MARK: - Data

    @MainActor
    override func data(ofType _: String) throws -> Data {
        guard let sourceEncoding, let data = (content?.string as NSString?)?.data(using: sourceEncoding.nsValue) else {
            Self.logger.error("Failed to encode contents to \(self.sourceEncoding.debugDescription)")
            throw CodeFileError.failedToEncode
        }
        return data
    }

    // MARK: - Read

    /// Decodes a file's bytes into ``content`` using one of ``FileEncoding``'s supported encodings.
    ///
    /// Encoding contract (decided for this fork; the plain editor has no QLPreview fallback path):
    /// the editor window always shows either real decoded text or an explicit error alert, never a
    /// silent blank. When the bytes match none of the supported decodings, this throws
    /// ``CodeFileError/failedToDecode`` so NSDocument presents an error and opens nothing, rather
    /// than returning silently and leaving an empty, unlabeled window while the status bar claims
    /// "UTF-8". Latin-1 and Windows-1252 are supported decodings, so ordinary single-byte text
    /// files open as real text instead of failing.
    override func read(from data: Data, ofType _: String) throws {
        guard let decoded = Self.decode(data: data) else {
            #if DEBUG
            debugRuntimeLog("Failed to read file: no supported encoding matched (\(data.count) bytes)")
            #endif
            // No supported decoding matched. Surface a real error so the open fails visibly
            // instead of leaving a blank window (sourceEncoding stays nil -> status "Unknown").
            throw CodeFileError.failedToDecode
        }
        MainActor.assumeIsolated {
            self.sourceEncoding = decoded.encoding
            if let content {
                // Reload (external change) path: replacing the text via setString
                // mutates the shared storage directly and bypasses the TextView
                // change notification, so onTextChange never fires and no
                // highlight is scheduled for the new content. Schedule one here
                // so a presentedItemDidChange reload stays highlighted.
                content.mutableString.setString(decoded.text)
                PlainSyntaxHighlighter.highlight(storage: content, language: getLanguage())
                // A reload replaced the whole buffer without going through the editor's
                // per-mutation edit path, so consumers rescan the entire document. This
                // is the full-invalidation case of the edited-range contract (reload only;
                // Clean Text edits through replaceCharacters), distinct from a range edit.
                broadcast(.fullInvalidation)
                #if DEBUG
                // Emitted after the storage swap and the full-invalidation broadcast so
                // an unattended e2e can await reload completion instead of polling.
                debugRuntimeLog("RELOAD_COMPLETE path: \(self.fileURL?.path ?? "<unknown>")")
                #endif
            } else {
                self.content = NSTextStorage(string: decoded.text)
            }
            #if DEBUG
            Self.logLoadedFile(self)
            #endif
            NotificationCenter.default.post(name: Self.didOpenNotification, object: self)
        }
    }

    /// Decodes file bytes into text plus the ``FileEncoding`` that produced it, or `nil` when no
    /// supported decoding matches.
    ///
    /// A BOM-less UTF-16 file (LE or BE) runs through ``plausibleBomlessUTF16Encoding(in:)`` first:
    /// its interleaved 0x00 bytes are valid standalone UTF-8 NULs, so Foundation's heuristic below
    /// confidently misreports UTF-8 and the NULs survive into the decoded string uncaught. Files
    /// that already carry a byte-order mark skip this pre-check entirely and fall through to the
    /// heuristic, which already resolves BOM'd UTF-16 correctly (the BOM removes the ambiguity the
    /// heuristic otherwise has, and it strips the BOM from the returned string).
    ///
    /// Otherwise, primary detection uses Foundation's heuristic over the suggested encodings, which
    /// handles byte-order marks and Unicode content confidently. That heuristic can misjudge a
    /// short, mostly-ASCII file carrying a single high byte (for example "Caf\u{E9}\n") as UTF-8 and
    /// then fail to convert it; for that case we fall back to an explicit Windows-1252 decode. The
    /// fallback also covers ISO Latin-1 text because bytes 0xA0-0xFF are identical in both. Bytes
    /// undefined in Windows-1252 (0x81, 0x8D, 0x8F, 0x90, 0x9D) fail every path deliberately, so a
    /// genuinely undecodable file returns `nil` and the caller raises the decode error.
    nonisolated private static func decode(data: Data) -> (text: String, encoding: FileEncoding)? {
        if let utf16Encoding = plausibleBomlessUTF16Encoding(in: data),
           let text = String(data: data, encoding: utf16Encoding) {
            let fileEncoding: FileEncoding = utf16Encoding == .utf16LittleEndian ? .utf16LE : .utf16BE
            return (text, fileEncoding)
        }
        var nsString: NSString?
        let rawEncoding = NSString.stringEncoding(
            for: data,
            encodingOptions: [
                .allowLossyKey: false, // Fail if using lossy encoding.
                .suggestedEncodingsKey: FileEncoding.allCases.map { $0.nsValue },
                .useOnlySuggestedEncodingsKey: true
            ],
            convertedString: &nsString,
            usedLossyConversion: nil
        )
        if let encoding = FileEncoding(rawEncoding), let nsString {
            return (nsString as String, encoding)
        }
        // Deterministic fallback for files the heuristic misjudged as UTF-8.
        if let text = String(data: data, encoding: .windowsCP1252) {
            return (text, .windows1252)
        }
        return nil
    }

    /// Detects a BOM-less UTF-16 (LE or BE) plausibility pattern in a bounded prefix of `data`, or
    /// `nil` when the data does not look like BOM-less UTF-16.
    ///
    /// Samples at most the first 4 KiB (large files do not need more to decide) as byte pairs.
    /// UTF-16LE ASCII-range text puts the character byte first and a 0x00 high byte second; UTF-16BE
    /// puts them in the mirrored order. A file only qualifies when at least 2 pairs were sampled
    /// (a 1-byte or empty file can never plausibly be UTF-16) and over 60% of sampled pairs match
    /// one direction's pattern. The 60% threshold is conservative on purpose: ordinary UTF-8 and
    /// Windows-1252 text never carries an interleaved 0x00 byte in most character pairs, so those
    /// files score near 0% and can never cross the threshold by accident.
    ///
    /// Files that already carry a recognized byte-order mark are excluded up front, since
    /// Foundation's `NSString` heuristic already decodes BOM'd UTF-16 (and UTF-8, UTF-32) correctly.
    nonisolated private static func plausibleBomlessUTF16Encoding(in data: Data) -> String.Encoding? {
        let byteOrderMarks: [[UInt8]] = [
            [0xEF, 0xBB, 0xBF], // UTF-8 BOM
            [0xFF, 0xFE, 0x00, 0x00], // UTF-32LE BOM (checked before the shorter UTF-16LE BOM below)
            [0x00, 0x00, 0xFE, 0xFF], // UTF-32BE BOM
            [0xFF, 0xFE], // UTF-16LE BOM
            [0xFE, 0xFF] // UTF-16BE BOM
        ]
        for bom in byteOrderMarks where data.starts(with: bom) {
            return nil
        }

        let sampleSize = min(data.count, 4096)
        let pairCount = sampleSize / 2
        guard pairCount >= 2 else {
            return nil
        }

        let sampledBytes = [UInt8](data.prefix(sampleSize))
        var littleEndianMatches = 0
        var bigEndianMatches = 0
        for pairIndex in 0..<pairCount {
            let firstByte = sampledBytes[pairIndex * 2]
            let secondByte = sampledBytes[pairIndex * 2 + 1]
            if secondByte == 0x00 && isPlausibleAsciiTextByte(firstByte) {
                littleEndianMatches += 1
            }
            if firstByte == 0x00 && isPlausibleAsciiTextByte(secondByte) {
                bigEndianMatches += 1
            }
        }

        let matchThreshold = Double(pairCount) * 0.6
        if Double(littleEndianMatches) > matchThreshold {
            return .utf16LittleEndian
        }
        if Double(bigEndianMatches) > matchThreshold {
            return .utf16BigEndian
        }
        return nil
    }

    /// A byte plausible as the non-zero half of an ASCII-range UTF-16 code unit: printable ASCII,
    /// plus tab, newline, and carriage return.
    nonisolated private static func isPlausibleAsciiTextByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x09, 0x0A, 0x0D, 0x20...0x7E:
            return true
        default:
            return false
        }
    }

    /// If ``hasUnautosavedChanges`` is `true` and an autosave has not already been scheduled, schedules a new autosave.
    /// If ``hasUnautosavedChanges`` is `false`, cancels any scheduled timers and returns.
    ///
    /// All operations are done with the ``autosaveTimerLock`` acquired (including the scheduled autosave) to ensure
    /// correct timing when scheduling or cancelling timers.
    @MainActor
    override func scheduleAutosaving() {
        autosaveTimerLock.withLock {
            if self.hasUnautosavedChanges {
                guard autosaveTimer == nil else { return }
                autosaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] timer in
                    let shouldAutosave = timer.isValid
                    Task { @MainActor [weak self] in
                        self?.autosaveTimerLock.withLock {
                            guard shouldAutosave else { return }
                            self?.autosaveTimer = nil
                            self?.autosave(withDelegate: nil, didAutosave: nil, contextInfo: nil)
                        }
                    }
                }
            } else {
                autosaveTimer?.invalidate()
                autosaveTimer = nil
            }
        }
    }

    // MARK: - External Changes

    /// The result of probing the represented file's current on-disk state. Kept
    /// distinct from a bare `Date?` so a stat failure (`unreadable`) no longer
    /// collapses into the same `nil` a genuine "file is gone" (`missing`) or a
    /// present mtime would produce -- the old `getModificationDate()` returned
    /// `nil` for all three, so a transient stat failure masqueraded as "no change."
    private enum FileModificationProbe {
        /// The file exists and here is its current modification date.
        case date(Date)
        /// The file no longer exists at `fileURL` (deleted or moved).
        case missing
        /// The file could not be stat'd for a reason other than absence.
        case unreadable
    }

    /// Handle the notification that the represented file item changed.
    ///
    /// Routes to the five-case external-change matrix. The mtime probe is
    /// read off the main actor; every decision, buffer read, and state change runs
    /// on the main actor so AppKit document state stays isolated correctly.
    override func presentedItemDidChange() {
        Task { @MainActor [weak self] in
            self?.handlePresentedItemChange()
        }
    }

    /// The represented file was deleted or moved out from under an open document.
    /// NSFilePresenter delivers this on its own path (not `presentedItemDidChange`,
    /// whose mtime probe needs the file to still exist), so the deleted/moved
    /// matrix row is handled here as well.
    override func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        Task { @MainActor [weak self] in
            self?.handleFileDeletedOrMoved()
        }
        completionHandler(nil)
    }

    /// Dispatches an external change to the matrix row it belongs to.
    @MainActor
    private func handlePresentedItemChange() {
        switch probeModificationDate() {
        case .missing:
            // File deleted or moved: alert, needs Save As, edits kept.
            handleFileDeletedOrMoved()
        case .unreadable:
            // Could not stat for a reason other than deletion. Do not treat this
            // as "no change" and do not advance the date; wait for a later,
            // readable notification rather than acting on an unknown state.
            #if DEBUG
            debugRuntimeLog("EXTERNAL_CHANGE probe=unreadable path: \(fileURL?.path ?? "<unknown>")")
            #endif
        case .date(let currentModificationDate):
            guard fileModificationDate != currentModificationDate else { return }
            handleExternalContentChange(currentModificationDate: currentModificationDate)
        }
    }

    /// Applies the four content-change rows (clean/dirty crossed with
    /// decodable/undecodable) for a file that still exists but changed on disk.
    @MainActor
    private func handleExternalContentChange(currentModificationDate: Date) {
        guard let fileURL, let fileType else { return }

        if isDocumentEdited {
            // Dirty document: never overwrite the buffer without the user's
            // choice. Classify the external bytes first, without mutating content.
            let externalIsDecodable = (try? Data(contentsOf: fileURL))
                .map { Self.decode(data: $0) != nil } ?? false
            if externalIsDecodable {
                // Dirty + decodable: acknowledge we have observed this on-disk
                // version (so the same change is not re-prompted) and ask the user
                // to keep their edits or reload. The buffer is untouched until then.
                fileModificationDate = currentModificationDate
                surfaceReloadConflict()
            } else {
                // Dirty + undecodable: error alert, edits kept, date not advanced.
                surfaceExternalChangeAlert(.undecodable)
            }
            return
        }

        // Clean document. A decode failure must never advance the modification date
        // behind stale text (audit F3): classify the external bytes before touching
        // the buffer, so only a decodable change reloads and only then is the date
        // advanced to acknowledge the buffer now matches disk.
        let externalIsDecodable = (try? Data(contentsOf: fileURL))
            .map { Self.decode(data: $0) != nil } ?? false
        guard externalIsDecodable else {
            // Clean + undecodable: error alert, buffer untouched, date not advanced.
            // The document must not claim to be caught up with disk behind content
            // it could not load.
            surfaceExternalChangeAlert(.undecodable)
            return
        }

        // Clean + decodable: silently reload the new content into the shared storage.
        // The reload replaces the whole buffer and broadcasts .fullInvalidation, which
        // the editor observes to refresh the encoding label (audit F7) and to reset the
        // now-stale undo stack (audit F4). Killing the old `try?` swallow, the read error
        // is surfaced rather than hidden, extending the "always real text or an
        // explicit error, never a silent blank" contract to the reload path. The date
        // advances only after the reload actually succeeds.
        do {
            try self.read(from: fileURL, ofType: fileType)
            fileModificationDate = currentModificationDate
        } catch {
            // The pre-check decoded these bytes, so a throw here is unexpected. Surface
            // it instead of swallowing it; read(from:ofType:) throws before mutating the
            // buffer, so the in-memory document is left untouched and the date unmoved.
            surfaceExternalChangeAlert(.undecodable)
        }
    }

    /// Surfaces the keep-mine-or-reload conflict. Under the DEBUG auto-answer
    /// launch argument it resolves immediately so an e2e run is unattended;
    /// otherwise it sets observable state the editor window renders as an alert.
    @MainActor
    private func surfaceReloadConflict() {
        #if DEBUG
        debugRuntimeLog("EXTERNAL_CHANGE_PROMPT kind=reloadConflict")
        if let choice = PlainEditorConflictAutoChoice.requested() {
            resolveExternalChangeConflict(reloadFromDisk: choice == .reload)
            return
        }
        #endif
        pendingExternalChange = .reloadConflict
    }

    /// Surfaces a single-button external-change alert (undecodable content or a
    /// deleted/moved file) as observable state the editor window renders.
    @MainActor
    private func surfaceExternalChangeAlert(_ prompt: ExternalChangePrompt) {
        #if DEBUG
        debugRuntimeLog("EXTERNAL_CHANGE_PROMPT kind=\(prompt)")
        #endif
        pendingExternalChange = prompt
    }

    /// The backing file was deleted or moved. Clear the file association so a
    /// later Save routes through Save As instead of writing to a path that no
    /// longer exists, keep the buffer, and mark it dirty so the window title
    /// reflects the unsaved state. Guarded so a notification storm surfaces once.
    @MainActor
    private func handleFileDeletedOrMoved() {
        guard fileURL != nil else { return }
        fileURL = nil
        updateChangeCount(.changeDone)
        surfaceExternalChangeAlert(.fileDeleted)
    }

    /// Resolves a keep-mine-or-reload conflict from the alert (or the DEBUG
    /// auto-answer seam). Keeping edits leaves the dirty buffer as-is; reloading
    /// replaces it with the on-disk text and clears the dirty flag, since the
    /// buffer once again matches saved state.
    @MainActor
    func resolveExternalChangeConflict(reloadFromDisk: Bool) {
        pendingExternalChange = nil
        guard reloadFromDisk else {
            #if DEBUG
            debugRuntimeLog("EXTERNAL_CHANGE_RESOLVED choice=keep")
            #endif
            return
        }
        guard let fileURL, let fileType else { return }
        do {
            try self.read(from: fileURL, ofType: fileType)
            // Reload succeeded: the buffer again matches the on-disk saved state, so
            // clear the dirty flag.
            updateChangeCount(.changeCleared)
            #if DEBUG
            debugRuntimeLog("EXTERNAL_CHANGE_RESOLVED choice=reload")
            #endif
        } catch {
            // The file changed again between prompt and click, or its new bytes no
            // longer decode, so the reload failed. The user's kept edits are still in
            // the buffer -- clearing the dirty flag here would mark the document clean
            // over unsaved content and lose those edits silently at the next close.
            // Leave the dirty flag alone and surface the failure instead. This is the
            // same silent `try?` swallow that the presentedItemDidChange reload path
            // also avoids.
            surfaceExternalChangeAlert(.undecodable)
            #if DEBUG
            debugRuntimeLog("EXTERNAL_CHANGE_RESOLVED choice=reload result=failed")
            #endif
        }
    }

    /// Dismisses a single-button external-change alert (undecodable or deleted).
    @MainActor
    func dismissExternalChangeAlert() {
        pendingExternalChange = nil
    }

    /// Probes the represented file's current on-disk modification state.
    ///
    /// Different from `NSDocument.fileModificationDate`, which stores the date that
    /// existed when the document last read the file. Distinguishes a present mtime,
    /// a missing file (deleted or moved), and an unreadable stat, so callers can
    /// route each to the right matrix row instead of conflating them as `nil`.
    nonisolated private func probeModificationDate() -> FileModificationProbe {
        guard let path = fileURL?.path else { return .unreadable }
        if !FileManager.default.fileExists(atPath: path) {
            return .missing
        }
        guard let date = try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date else {
            return .unreadable
        }
        return .date(date)
    }

    // MARK: - Close

    @MainActor
    override func close() {
        super.close()
        NotificationCenter.default.post(name: Self.didCloseNotification, object: fileURL)
    }

    @MainActor
    override func save(_ sender: Any?) {
        guard let fileURL else {
            super.save(sender)
            return
        }

        do {
            // Get parent directory for cases when entire folders were deleted - and recreate them as needed
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

            super.save(sender)
        } catch {
            presentError(error)
        }
    }

    override func fileNameExtension(
        forType typeName: String,
        saveOperation: NSDocument.SaveOperationType
    ) -> String? {
        MainActor.assumeIsolated {
            guard let fileTypeName = Self.fileTypeExtension[typeName] else {
                return super.fileNameExtension(forType: typeName, saveOperation: saveOperation)
            }
            return fileTypeName
        }
    }

    /// Determines the code language of the document.
    /// Use ``CodeFileDocument/language`` for the default value before using this. That property is used to override
    /// the file's language.
    /// - Returns: The detected code language.
    @MainActor
    func getLanguage() -> CodeLanguage {
        guard let url = fileURL else {
            return .default
        }
        return language ?? CodeLanguage.detectLanguageFrom(
            url: url,
            prefixBuffer: content?.string.getFirstLines(5),
            suffixBuffer: content?.string.getLastLines(5)
        )
    }

}
private extension CodeFileDocument {

    static let fileTypeExtension: [String: String?] = [
        "public.make-source": nil
    ]

    #if DEBUG
    // Built as concatenated segments (rather than one long interpolated literal) so the
    // line stays under SwiftLint's length limit; the emitted log text is unchanged. Kept
    // in this extension rather than the class body so it does not grow the class's
    // already-at-limit type_body_length.
    static func logLoadedFile(_ document: CodeFileDocument) {
        var message = "Loaded file: \(document.fileURL?.path ?? "<unknown>")"
        message += " characters: \(document.content?.length ?? 0)"
        debugRuntimeLog(message)
    }
    #endif
}
