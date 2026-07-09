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
import CodeEditHighlighting
import CodeEditSyntaxDefinitions

/// CodeFileView is just a wrapper of the `CodeEditor` dependency
struct CodeFileView: View {
    @ObservedObject private var codeFile: CodeFileDocument
    @StateObject private var chrome = PlainEditorChromeModel()
    @State private var activeTextView: TextView?
    @AppStorage("PlainEditor.fontFamily") private var editorFontFamily = PlainEditorFontSettings.defaultFontFamily
    @AppStorage("PlainEditor.fontSize") private var editorFontSize = PlainEditorFontSettings.defaultFontSize

    private let isEditable: Bool
    private let wrapLinesToEditorWidth = true
    private let useSystemCursor = true
    private var editorFont: NSFont {
        PlainEditorFontSettings.font(family: editorFontFamily, size: editorFontSize)
    }

    init(codeFile: CodeFileDocument, isEditable: Bool = true) {
        self._codeFile = .init(wrappedValue: codeFile)
        self.isEditable = isEditable
    }

    var body: some View {
        VStack(spacing: 0) {
            PlainEditorCommandBar(
                canSave: codeFile.isDocumentEdited || codeFile.fileURL != nil,
                canUndo: activeTextView?.undoManager?.canUndo ?? false,
                canRedo: activeTextView?.undoManager?.canRedo ?? false,
                canCleanText: activeTextView?.isEditable ?? false,
                fontFamily: $editorFontFamily,
                fontSize: $editorFontSize
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
                    font: editorFont,
                    textColor: .textColor,
                    lineHeightMultiplier: 1,
                    edgeInsets: .init(left: 12, right: 12),
                    textInsets: .init(left: 0, right: 0),
                    onTextChange: {
                        if let activeTextView {
                            PlainSyntaxHighlighter.highlight(textView: activeTextView, language: codeFile.getLanguage())
                        } else if let storage = codeFile.content {
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
                        PlainEditorActionRouter.shared.register(textView: textView)
                        PlainSyntaxHighlighter.highlight(textView: textView, language: codeFile.getLanguage())
                        chrome.refresh(document: codeFile, selection: textView.selectedRange())
                        #if DEBUG
                        PlainEditorCommandSelfTest.scheduleIfRequested(textView: textView)
                        #endif
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
            logFontSettings()
            #endif
        }
        .onChange(of: editorFontFamily) { _, _ in
            logFontSettings()
        }
        .onChange(of: editorFontSize) { _, _ in
            logFontSettings()
        }
    }

    private func logFontSettings() {
        #if DEBUG
        debugRuntimeLog("Plain editor font settings: family=\(editorFontFamily) size=\(editorFontSize)")
        #endif
    }
}

enum PlainEditorFontSettings {
    static let defaultFontFamily = "SF Mono"
    static let defaultFontSize = 13.0
    static let minimumFontSize = 9.0
    static let maximumFontSize = 32.0
    static let availableFontFamilies = [
        "SF Mono",
        "Menlo",
        "Monaco",
        "Courier New"
    ]

    static func font(family: String, size: Double) -> NSFont {
        let clampedSize = min(max(size, minimumFontSize), maximumFontSize)
        if family == defaultFontFamily {
            return .monospacedSystemFont(ofSize: clampedSize, weight: .regular)
        }
        guard let font = NSFont(name: family, size: clampedSize), font.isFixedPitch else {
            return .monospacedSystemFont(ofSize: clampedSize, weight: .regular)
        }
        return font
    }
}

#if DEBUG
@MainActor
private enum PlainEditorCommandSelfTest {
    private static var didSchedule = false

    static func scheduleIfRequested(textView: TextView) {
        guard ProcessInfo.processInfo.environment["CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST"] == "1",
              !didSchedule else {
            return
        }
        didSchedule = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            run(textView: textView)
        }
    }

    private static func run(textView: TextView) {
        let originalText = textView.string
        let originalSelection = textView.selectedRange()
        let originalPasteboard = NSPasteboard.general.string(forType: .string)
        let marker = "let plainEditorCommandSelfTestValue = 123\n"

        textView.window?.makeFirstResponder(textView)
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        textView.replaceCharacters(in: NSRange(location: 0, length: 0), with: marker)
        let inserted = textView.string.hasPrefix(marker)

        let undoSent = PlainEditorActionRouter.shared.undo()
        let undoWorked = undoSent && textView.string == originalText

        let redoSent = PlainEditorActionRouter.shared.redo()
        let redoWorked = redoSent && textView.string.hasPrefix(marker)

        let selectAllSent = PlainEditorActionRouter.shared.selectAll()
        let selectedAll = selectAllSent && textView.selectedRange().length == (textView.string as NSString).length

        // Copy value A (the marker) to the system pasteboard.
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: (marker as NSString).length))
        let copySent = PlainEditorActionRouter.shared.copy()
        let copied = copySent && NSPasteboard.general.string(forType: .string) == marker

        // Cut a distinct value B so the pasteboard now holds B, not the copied A.
        // Paste must then yield B, proving paste reads the live pasteboard and not a
        // stale internal copy buffer (regression guard for the paste-ordering bug).
        let cutMarker = "let plainEditorCommandCutValue = 456\n"
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        textView.replaceCharacters(in: NSRange(location: 0, length: 0), with: cutMarker)
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: (cutMarker as NSString).length))
        let cutSent = PlainEditorActionRouter.shared.cut()
        let cut = cutSent && !textView.string.hasPrefix(cutMarker)

        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        let pasteSent = PlainEditorActionRouter.shared.paste()
        let pasted = pasteSent && textView.string.hasPrefix(cutMarker)

        let dirtyLine = "let cleanTextSmokeValue = 1    \n"
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
        textView.replaceCharacters(in: NSRange(location: 0, length: 0), with: dirtyLine)
        let cleanSent = PlainEditorActionRouter.shared.cleanText()
        let cleanWorked = cleanSent && textView.string.hasPrefix("let cleanTextSmokeValue = 1\n")
        let cleanUndoSent = PlainEditorActionRouter.shared.undo()
        let cleanUndoWorked = cleanUndoSent && textView.string.hasPrefix(dirtyLine)
        let cleanRedoSent = PlainEditorActionRouter.shared.redo()
        let cleanRedoWorked = cleanRedoSent && textView.string.hasPrefix("let cleanTextSmokeValue = 1\n")

        debugRuntimeLog(
            "Plain editor command self-test: insert=\(inserted) undo=\(undoWorked) redo=\(redoWorked) selectAll=\(selectedAll) copy=\(copied) cut=\(cut) paste=\(pasted) cleanText=\(cleanWorked) cleanUndo=\(cleanUndoWorked) cleanRedo=\(cleanRedoWorked)"
        )

        let currentFullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.replaceCharacters(in: currentFullRange, with: originalText)
        let restoredSelection = if originalSelection.location != NSNotFound,
                                   originalSelection.location <= textView.textStorage.length {
            NSRange(
                location: originalSelection.location,
                length: min(originalSelection.length, textView.textStorage.length - originalSelection.location)
            )
        } else {
            NSRange(location: 0, length: 0)
        }
        textView.selectionManager.setSelectedRange(restoredSelection)

        NSPasteboard.general.clearContents()
        if let originalPasteboard {
            NSPasteboard.general.setString(originalPasteboard, forType: .string)
        }
    }
}
#endif

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

        cursorPosition = PlainEditorStatusReporter.cursorLabel(text: text, selection: selectedRange)
        lineCount = "\(max(1, text.components(separatedBy: .newlines).count)) lines"
        wordCount = "\(PlainEditorStatusReporter.wordCount(in: text)) words"
        characterCount = "\(nsText.length) characters"
        indentation = PlainEditorStatusReporter.indentationLabel(in: text)
        encoding = PlainEditorStatusReporter.encodingLabel(document.sourceEncoding)
        lineEnding = PlainEditorStatusReporter.lineEndingLabel(in: text)
        syntaxMode = PlainEditorStatusReporter.languageLabel(document.getLanguage())
        #if DEBUG
        debugRuntimeLog(
            "Plain editor status: cursor=\(cursorPosition) lines=\(lineCount) words=\(wordCount) chars=\(characterCount) indent=\(indentation) encoding=\(encoding) lineEnding=\(lineEnding) syntax=\(syntaxMode)"
        )
        #endif
    }

}

private struct PlainEditorCommandBar: View {
    let canSave: Bool
    let canUndo: Bool
    let canRedo: Bool
    let canCleanText: Bool
    @Binding var fontFamily: String
    @Binding var fontSize: Double

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
                _ = PlainEditorActionRouter.shared.undo()
            })
            commandButton("Redo", isEnabled: canRedo, action: {
                _ = PlainEditorActionRouter.shared.redo()
            })
            Divider().frame(height: 16)
            commandButton("Clean Text", isEnabled: canCleanText, action: {
                _ = PlainEditorActionRouter.shared.cleanText()
            })
            Spacer(minLength: 16)
            fontControls
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

    private var fontControls: some View {
        HStack(spacing: 8) {
            Text("\(Int(fontSize.rounded())) pt")
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)

            commandButton("A-", isEnabled: fontSize > PlainEditorFontSettings.minimumFontSize) {
                fontSize = max(PlainEditorFontSettings.minimumFontSize, fontSize - 1)
            }
            commandButton("A+", isEnabled: fontSize < PlainEditorFontSettings.maximumFontSize) {
                fontSize = min(PlainEditorFontSettings.maximumFontSize, fontSize + 1)
            }
            commandButton("Reset") {
                fontFamily = PlainEditorFontSettings.defaultFontFamily
                fontSize = PlainEditorFontSettings.defaultFontSize
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Editor font controls")
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
