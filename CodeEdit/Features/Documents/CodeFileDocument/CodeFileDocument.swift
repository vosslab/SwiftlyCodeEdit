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

    // MARK: - NSDocument

    override static var autosavesInPlace: Bool {
        true
    }

    override var autosavingFileType: String? {
        fileType
    }

    @MainActor
    override func makeWindowControllers() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        let windowController = NSWindowController(window: window)
        if let fileURL {
            windowController.shouldCascadeWindows = false
            if ProcessInfo.processInfo.environment["CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST"] == "1" {
                UserDefaults.standard.removeObject(forKey: "NSWindow Frame \(fileURL.path)")
            }
            windowController.windowFrameAutosaveName = fileURL.path
        }
        addWindowController(windowController)
        windowController.showWindow(nil)

        if let fileURL {
            window.title = fileURL.lastPathComponent
        }
        window.contentView = NSHostingView(rootView: WindowCodeFileView(codeFile: self))
        #if DEBUG
        debugRuntimeLog("Created editor window for \(self.fileURL?.path ?? "<unknown>")")
        #endif

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        // Fires on the first document window only; must run before highlighting
        // (WP-Q0 made the first highlight async) so the marker reflects launch-to-paint.
        CodeEditMain.logLaunchToWindowIfNeeded()

        if let fileURL, UserDefaults.standard.object(forKey: "NSWindow Frame \(fileURL.path)") == nil {
            window.center()
        }
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
            } else {
                self.content = NSTextStorage(string: decoded.text)
            }
            #if DEBUG
            debugRuntimeLog("Loaded file: \(self.fileURL?.path ?? "<unknown>") characters: \(self.content?.length ?? 0)")
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
    private nonisolated static func decode(data: Data) -> (text: String, encoding: FileEncoding)? {
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
    private nonisolated static func plausibleBomlessUTF16Encoding(in data: Data) -> String.Encoding? {
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
    private nonisolated static func isPlausibleAsciiTextByte(_ byte: UInt8) -> Bool {
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

    /// Handle the notification that the represented file item changed.
    ///
    /// We check if a file has been modified and can be read again to display to the user.
    /// To determine if a file has changed, we check the modification date. If it's different from the stored one,
    /// we continue.
    /// To determine if we can reload the file, we check if the document has outstanding edits. If not, we reload the
    /// file.
    override func presentedItemDidChange() {
        let currentModificationDate = getModificationDate()

        Task { @MainActor [weak self] in
            guard let self else { return }
            if fileModificationDate != currentModificationDate {
                guard isDocumentEdited else {
                    fileModificationDate = currentModificationDate
                    if let fileURL, let fileType {
                        // Reload on the main actor so we keep AppKit state isolated correctly.
                        try? self.read(from: fileURL, ofType: fileType)
                    }
                    return
                }
            }
        }
    }

    /// Helper to find the last modified date of the represented file item.
    /// 
    /// Different from `NSDocument.fileModificationDate`. This returns the *current* modification date, whereas the
    /// alternative stores the date that existed when we last read the file.
    nonisolated private func getModificationDate() -> Date? {
        guard let path = fileURL?.path else { return nil }
        return try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
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
}