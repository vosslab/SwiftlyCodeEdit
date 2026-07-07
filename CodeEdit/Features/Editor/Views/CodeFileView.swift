//
//  CodeFileView.swift
//  CodeEditModules/CodeFile
//
//  Created by Marco Carnevali on 17/03/22.
//

import Foundation
import SwiftUI
import CodeEditTextView
import CodeEditLanguages

/// CodeFileView is just a wrapper of the `CodeEditor` dependency
struct CodeFileView: View {
    @ObservedObject private var codeFile: CodeFileDocument
    @StateObject private var chrome = PlainEditorChromeModel()
    @State private var activeTextView: TextView?

    private let isEditable: Bool
    private let wrapLinesToEditorWidth = true
    private let useSystemCursor = true

    init(codeFile: CodeFileDocument, isEditable: Bool = true) {
        self._codeFile = .init(wrappedValue: codeFile)
        self.isEditable = isEditable
    }

    var body: some View {
        VStack(spacing: 0) {
            PlainEditorCommandBar(
                canSave: codeFile.isDocumentEdited || codeFile.fileURL != nil,
                canUndo: activeTextView?.undoManager?.canUndo ?? false,
                canRedo: activeTextView?.undoManager?.canRedo ?? false
            )

            ZStack(alignment: .topLeading) {
                PlainTextEditorView(
                    textStorage: Binding(
                        get: { codeFile.content ?? NSTextStorage() },
                        set: { codeFile.content = $0 }
                    ),
                    isEditable: isEditable,
                    isSelectable: true,
                    wrapLines: wrapLinesToEditorWidth,
                    useSystemCursor: useSystemCursor,
                    font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                    textColor: .textColor,
                    lineHeightMultiplier: 1,
                    edgeInsets: .init(left: 12, right: 12),
                    textInsets: .init(left: 0, right: 0),
                    onTextChange: {
                        if let storage = codeFile.content {
                            PlainSyntaxHighlighter.highlight(storage: storage, language: codeFile.getLanguage())
                        }
                        chrome.refresh(document: codeFile, selection: activeTextView?.selectedRange())
                        codeFile.updateChangeCount(.changeDone)
                    },
                    onSelectionChange: { selection in
                        chrome.refresh(document: codeFile, selection: selection)
                    },
                    onTextStorageReady: { storage in
                        PlainSyntaxHighlighter.highlight(storage: storage, language: codeFile.getLanguage())
                    },
                    onTextViewReady: { textView in
                        activeTextView = textView
                        chrome.refresh(document: codeFile, selection: textView.selectedRange())
                    }
                )
                // This view needs to refresh when the codefile changes. The file URL is too stable.
                .id(ObjectIdentifier(codeFile))
                .background(Color(nsColor: .textBackgroundColor))
                // minHeight zero fixes a bug where the app would freeze if the contents of the file are empty.
                .frame(minHeight: .zero, maxHeight: .infinity)

                if codeFile.content?.length == 0 {
                    Text("Open a source file to begin editing")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }

            PlainEditorStatusBar(chrome: chrome)
        }
        .onAppear {
            chrome.refresh(document: codeFile, selection: activeTextView?.selectedRange())
            #if DEBUG
            debugRuntimeLog("CodeFileView appeared length=\(codeFile.content?.length ?? 0) editable=\(isEditable)")
            debugRuntimeLog("Plain editor command ribbon ready")
            debugRuntimeLog("Plain editor status bar ready")
            #endif
        }
    }
}

@MainActor
final class PlainEditorChromeModel: ObservableObject {
    @Published var cursorPosition = "--"
    @Published var lineCount = "--"
    @Published var wordCount = "--"
    @Published var characterCount = "--"
    @Published var indentation = "--"
    @Published var encoding = "--"
    @Published var lineEnding = "--"
    @Published var syntaxMode = "--"

    func refresh(document: CodeFileDocument, selection: NSRange?) {
        let text = document.content?.string ?? ""
        let nsText = text as NSString
        let selectedRange = selection ?? NSRange(location: 0, length: 0)

        cursorPosition = Self.cursorLabel(text: text, selection: selectedRange)
        lineCount = "\(max(1, text.components(separatedBy: .newlines).count)) lines"
        wordCount = "\(Self.wordCount(in: text)) words"
        characterCount = "\(nsText.length) characters"
        indentation = Self.indentationLabel(in: text)
        encoding = Self.encodingLabel(document.sourceEncoding)
        lineEnding = Self.lineEndingLabel(in: text)
        syntaxMode = Self.languageLabel(document.getLanguage())
        #if DEBUG
        debugRuntimeLog(
            "Plain editor status: cursor=\(cursorPosition) lines=\(lineCount) words=\(wordCount) chars=\(characterCount) indent=\(indentation) encoding=\(encoding) lineEnding=\(lineEnding) syntax=\(syntaxMode)"
        )
        #endif
    }

    private static func cursorLabel(text: String, selection: NSRange) -> String {
        let nsText = text as NSString
        let cappedLocation = max(0, min(selection.location, nsText.length))
        let lineRange = nsText.lineRange(for: NSRange(location: cappedLocation, length: 0))
        let lineNumber = nsText.substring(to: cappedLocation).components(separatedBy: .newlines).count
        let currentLine = nsText.substring(with: lineRange)
        let column = currentLine.prefix(max(0, cappedLocation - lineRange.location)).count + 1
        return "\(lineNumber)/\(nsText.components(separatedBy: .newlines).count):\(column)"
    }

    private static func wordCount(in text: String) -> Int {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "_" }.count
    }

    private static func indentationLabel(in text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let sample = lines.prefix(50)
        var tabCount = 0
        var spaceCounts: [Int: Int] = [:]

        for line in sample {
            if line.hasPrefix("\t") {
                tabCount += 1
            } else if let count = line.prefix(while: { $0 == " " }).count.nonZero {
                spaceCounts[count, default: 0] += 1
            }
        }

        if tabCount > spaceCounts.values.reduce(0, +) {
            return "Tabs"
        }

        if let best = spaceCounts.max(by: { $0.value < $1.value })?.key {
            return "Soft Tabs: \(best)"
        }

        return "Unknown"
    }

    private static func lineEndingLabel(in text: String) -> String {
        if text.contains("\r\n") {
            return "CRLF"
        } else if text.contains("\r") {
            return "CR"
        } else if text.contains("\n") {
            return "LF"
        } else {
            return "Unknown"
        }
    }

    private static func encodingLabel(_ encoding: FileEncoding?) -> String {
        guard let encoding else {
            return "UTF-8"
        }

        switch encoding {
        case .utf8:
            return "UTF-8"
        default:
            return String(describing: encoding)
        }
    }

    private static func languageLabel(_ language: CodeLanguage) -> String {
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
}

private struct PlainEditorCommandBar: View {
    let canSave: Bool
    let canUndo: Bool
    let canRedo: Bool

    var body: some View {
        HStack(spacing: 10) {
            commandButton("New", action: {
                NSDocumentController.shared.newDocument(nil)
            })
            commandButton("Open...", action: {
                NSDocumentController.shared.openDocument(nil)
            })
            Divider().frame(height: 16)
            commandButton("Save", isEnabled: canSave, action: {
                NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
            })
            commandButton("Save As...", isEnabled: canSave, action: {
                NSApp.sendAction(#selector(NSDocument.saveAs(_:)), to: nil, from: nil)
            })
            Divider().frame(height: 16)
            commandButton("Undo", isEnabled: canUndo, action: {
                NSApp.sendAction(#selector(UndoManager.undo), to: nil, from: nil)
            })
            commandButton("Redo", isEnabled: canRedo, action: {
                NSApp.sendAction(#selector(UndoManager.redo), to: nil, from: nil)
            })
            Divider().frame(height: 16)
            commandButton("Clean Text", isEnabled: false, action: { })
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func commandButton(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderless)
            .disabled(!isEnabled)
    }
}

private struct PlainEditorStatusBar: View {
    @ObservedObject var chrome: PlainEditorChromeModel

    var body: some View {
        HStack(spacing: 14) {
            Text(chrome.cursorPosition)
            Text(chrome.lineCount)
            Text(chrome.wordCount)
            Text(chrome.characterCount)
            Text(chrome.indentation)
            Text(chrome.encoding)
            Text(chrome.lineEnding)
            Text(chrome.syntaxMode)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
}

private extension Int {
    var nonZero: Int? {
        self == 0 ? nil : self
    }
}
