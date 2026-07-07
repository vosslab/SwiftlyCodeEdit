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

enum CodeFileError: Error {
    case failedToDecode
    case failedToEncode
    case fileTypeError
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
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        let windowController = NSWindowController(window: window)
        if let fileURL {
            windowController.shouldCascadeWindows = false
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

    /// This function is used for decoding files.
    /// It should not throw error as unsupported files can still be opened by QLPreviewView.
    override func read(from data: Data, ofType _: String) throws {
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
        guard let validEncoding = FileEncoding(rawEncoding), let nsString else {
            #if DEBUG
            debugRuntimeLog("Failed to read file from data using encoding: \(rawEncoding)")
            #endif
            return
        }
        MainActor.assumeIsolated {
            self.sourceEncoding = validEncoding
            if let content {
                content.mutableString.setString(nsString as String)
            } else {
                self.content = NSTextStorage(string: nsString as String)
            }
            #if DEBUG
            debugRuntimeLog("Loaded file: \(self.fileURL?.path ?? "<unknown>") characters: \(self.content?.length ?? 0)")
            #endif
            NotificationCenter.default.post(name: Self.didOpenNotification, object: self)
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
