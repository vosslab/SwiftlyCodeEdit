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
import Combine

/// CodeFileView is just a wrapper of the `CodeEditor` dependency
struct CodeFileView: View {
    @ObservedObject private var editorInstance: EditorInstance
    @ObservedObject private var codeFile: CodeFileDocument

    @AppSettings(\.textEditing.defaultTabWidth)
    var defaultTabWidth
    @AppSettings(\.textEditing.indentOption)
    var indentOption
    @AppSettings(\.textEditing.lineHeightMultiple)
    var lineHeightMultiple
    @AppSettings(\.textEditing.wrapLinesToEditorWidth)
    var wrapLinesToEditorWidth
    @AppSettings(\.textEditing.overscroll)
    var overscroll
    @AppSettings(\.textEditing.font)
    var settingsFont
    @AppSettings(\.theme.useThemeBackground)
    var useThemeBackground
    @AppSettings(\.theme.matchAppearance)
    var matchAppearance
    @AppSettings(\.textEditing.letterSpacing)
    var letterSpacing
    @AppSettings(\.textEditing.bracketEmphasis)
    var bracketEmphasis
    @AppSettings(\.textEditing.useSystemCursor)
    var useSystemCursor
    @AppSettings(\.textEditing.showGutter)
    var showGutter
    @AppSettings(\.textEditing.showMinimap)
    var showMinimap
    @AppSettings(\.textEditing.showFoldingRibbon)
    var showFoldingRibbon
    @AppSettings(\.textEditing.reformatAtColumn)
    var reformatAtColumn
    @AppSettings(\.textEditing.showReformattingGuide)
    var showReformattingGuide
    @AppSettings(\.textEditing.invisibleCharacters)
    var invisibleCharactersConfiguration
    @AppSettings(\.textEditing.warningCharacters)
    var warningCharacters

    @Environment(\.colorScheme)
    private var colorScheme

    @EnvironmentObject var undoRegistration: UndoManagerRegistration

    @ObservedObject private var themeModel: ThemeModel = .shared

    private var cancellables = Set<AnyCancellable>()

    private let isEditable: Bool

    init(
        editorInstance: EditorInstance,
        codeFile: CodeFileDocument,
        textViewCoordinators: [TextViewCoordinator] = [],
        isEditable: Bool = true
    ) {
        self._editorInstance = .init(wrappedValue: editorInstance)
        self._codeFile = .init(wrappedValue: codeFile)
        self.isEditable = isEditable

        if let openOptions = codeFile.openOptions {
            codeFile.openOptions = nil
            editorInstance.cursorPositions = openOptions.cursorPositions
        }

        codeFile
            .contentCoordinator
            .textUpdatePublisher
            .sink { [weak codeFile] _ in
                codeFile?.updateChangeCount(.changeDone)
            }
            .store(in: &cancellables)
    }

    private var currentTheme: Theme {
        themeModel.selectedTheme ?? themeModel.themes.first!
    }

    @State private var font: NSFont = Settings[\.textEditing].font.current

    @Environment(\.edgeInsets)
    private var edgeInsets

    var body: some View {
        PlainTextEditorView(
            textStorage: Binding(
                get: { codeFile.content ?? NSTextStorage() },
                set: { codeFile.content = $0 }
            ),
            isEditable: isEditable,
            isSelectable: true,
            wrapLines: wrapLinesToEditorWidth,
            useSystemCursor: useSystemCursor,
            font: font,
            textColor: currentTheme.editor.text.nsColor,
            lineHeightMultiplier: lineHeightMultiple,
            edgeInsets: edgeInsets.horizontalEdgeInsets,
            textInsets: .init(left: 0, right: 0)
        )
        // This view needs to refresh when the codefile changes. The file URL is too stable.
        .id(ObjectIdentifier(codeFile))
        .background {
            if colorScheme == .dark {
                EffectView(.underPageBackground)
            } else {
                EffectView(.contentBackground)
            }
        }
        .colorScheme(currentTheme.appearance == .dark ? .dark : .light)
        // minHeight zero fixes a bug where the app would freeze if the contents of the file are empty.
        .frame(minHeight: .zero, maxHeight: .infinity)
        .onChange(of: settingsFont) { _, newFontSetting in
            font = newFontSetting.current
        }
    }
}
