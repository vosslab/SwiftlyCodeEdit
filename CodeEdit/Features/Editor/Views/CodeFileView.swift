//
//  CodeFileView.swift
//  CodeEditModules/CodeFile
//
//  Created by Marco Carnevali on 17/03/22.
//

import Foundation
import SwiftUI
import CodeEditTextView

/// CodeFileView is just a wrapper of the `CodeEditor` dependency
struct CodeFileView: View {
    @ObservedObject private var codeFile: CodeFileDocument

    private let isEditable: Bool
    private let wrapLinesToEditorWidth = true
    private let useSystemCursor = true

    init(codeFile: CodeFileDocument, isEditable: Bool = true) {
        self._codeFile = .init(wrappedValue: codeFile)
        self.isEditable = isEditable
    }

    var body: some View {
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
                    codeFile.updateChangeCount(.changeDone)
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
        .onAppear {
            #if DEBUG
            debugRuntimeLog("CodeFileView appeared length=\(codeFile.content?.length ?? 0) editable=\(isEditable)")
            #endif
        }
    }
}
