import AppIntents
import Foundation
import UniformTypeIdentifiers

@MainActor
enum PlainEditorSmokeIntentRunner {
    private static var currentDocument: CodeFileDocument?
    private static var currentFileURL: URL?
    private static var lastEditMarker: String?

    static func openKnownFile(path: String) throws -> String {
        let fileURL = URL(fileURLWithPath: path)
        let document = try openDocument(at: fileURL)
        currentDocument = document
        currentFileURL = fileURL
        return "loaded path=\(fileURL.path) characters=\(document.content?.length ?? 0)"
    }

    static func reportEditorState() throws -> String {
        guard let document = currentDocument, let fileURL = currentFileURL else {
            throw PlainEditorSmokeIntentError.noOpenDocument
        }
        let text = document.content?.string ?? ""
        let language = document.getLanguage().id.rawValue
        let wordCount = PlainEditorStatusReporter.wordCount(in: text)
        let indentation = PlainEditorStatusReporter.indentationLabel(in: text)
        let encoding = PlainEditorStatusReporter.encodingLabel(document.sourceEncoding)
        let lineEnding = PlainEditorStatusReporter.lineEndingLabel(in: text)
        return "state path=\(fileURL.path) characters=\(document.content?.length ?? 0) words=\(wordCount) language=\(language) indentation=\(indentation) encoding=\(encoding) lineEnding=\(lineEnding)"
    }

    static func applySyntheticEdit(marker: String) throws -> String {
        guard let document = currentDocument, let content = document.content else {
            throw PlainEditorSmokeIntentError.noOpenDocument
        }
        content.mutableString.insert(marker, at: 0)
        document.updateChangeCount(.changeDone)
        lastEditMarker = marker
        return "edited markerLength=\((marker as NSString).length) characters=\(content.length)"
    }

    static func saveCurrentDocument() throws -> String {
        guard let document = currentDocument, let fileURL = currentFileURL else {
            throw PlainEditorSmokeIntentError.noOpenDocument
        }
        document.sourceEncoding = document.sourceEncoding ?? .utf8
        try document.write(to: fileURL, ofType: UTType.sourceCode.identifier)
        document.updateChangeCount(.changeCleared)
        return "saved path=\(fileURL.path) characters=\(document.content?.length ?? 0)"
    }

    static func reopenAndVerify() throws -> String {
        guard let fileURL = currentFileURL, let lastEditMarker else {
            throw PlainEditorSmokeIntentError.noOpenDocument
        }
        let reopened = try openDocument(at: fileURL)
        let persisted = reopened.content?.string.hasPrefix(lastEditMarker) == true
        currentDocument = reopened
        return "reopened path=\(fileURL.path) characters=\(reopened.content?.length ?? 0) persisted=\(persisted)"
    }

    static func reset() {
        currentDocument = nil
        currentFileURL = nil
        lastEditMarker = nil
    }

    private static func openDocument(at fileURL: URL) throws -> CodeFileDocument {
        let documentType = UTType(filenameExtension: fileURL.pathExtension)?.identifier ?? UTType.sourceCode.identifier
        return try CodeFileDocument(for: fileURL, withContentsOf: fileURL, ofType: documentType)
    }

}

enum PlainEditorSmokeIntentError: Error, CustomStringConvertible {
    case noOpenDocument

    var description: String {
        switch self {
        case .noOpenDocument:
            return "No plain-editor smoke document is open."
        }
    }
}

struct OpenKnownFileIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Known Plain Editor File"
    static let description = IntentDescription("Open a known text or source file through the plain editor smoke path.")

    @Parameter(title: "Path")
    var path: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await MainActor.run {
            try PlainEditorSmokeIntentRunner.openKnownFile(path: path)
        }
        return .result(value: result)
    }
}

struct ReportEditorStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Report Plain Editor State"
    static let description = IntentDescription("Report loaded plain editor document state for smoke validation.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await MainActor.run {
            try PlainEditorSmokeIntentRunner.reportEditorState()
        }
        return .result(value: result)
    }
}

struct ApplySyntheticEditIntent: AppIntent {
    static let title: LocalizedStringResource = "Apply Plain Editor Synthetic Edit"
    static let description = IntentDescription("Apply a deterministic edit to the open plain editor smoke document.")

    @Parameter(title: "Marker")
    var marker: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await MainActor.run {
            try PlainEditorSmokeIntentRunner.applySyntheticEdit(marker: marker)
        }
        return .result(value: result)
    }
}

struct SaveCurrentDocumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Plain Editor Smoke Document"
    static let description = IntentDescription("Save the current plain editor smoke document.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await MainActor.run {
            try PlainEditorSmokeIntentRunner.saveCurrentDocument()
        }
        return .result(value: result)
    }
}

struct ReopenAndVerifyIntent: AppIntent {
    static let title: LocalizedStringResource = "Reopen And Verify Plain Editor Smoke Document"
    static let description = IntentDescription("Reopen the smoke document and verify the synthetic edit persisted.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await MainActor.run {
            try PlainEditorSmokeIntentRunner.reopenAndVerify()
        }
        return .result(value: result)
    }
}
