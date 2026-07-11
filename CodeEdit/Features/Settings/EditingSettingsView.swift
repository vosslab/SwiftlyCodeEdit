//
//  EditingSettingsView.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-10.
//

import SwiftUI

/// The Settings scene's "Editing" pane: indentation style and width, and the
/// default line ending for newly created files (LF per the plan's Resolved
/// decisions). These persist to `PlainEditorSettingsKeys`, but neither is
/// consumed by the editor yet -- auto-indent behavior and new-document line
/// endings land with the document-side packages. The Settings pane only
/// persists and exposes the settings.
struct EditingSettingsView: View {
    @AppStorage(PlainEditorSettingsKeys.indentationStyle)
    private var indentationStyle = IndentationStyle.spaces.rawValue
    @AppStorage(PlainEditorSettingsKeys.indentationWidth)
    private var indentationWidth = 4
    @AppStorage(PlainEditorSettingsKeys.defaultLineEnding)
    private var defaultLineEnding = LineEndingPreference.lf.rawValue

    var body: some View {
        Form {
            Picker("Indentation", selection: $indentationStyle) {
                ForEach(IndentationStyle.allCases) { style in
                    Text(style.displayName).tag(style.rawValue)
                }
            }

            Stepper(
                "Indent Width: \(indentationWidth) \(indentationWidth == 1 ? "space" : "spaces")",
                value: $indentationWidth,
                in: 1...8
            )

            Picker("Default Line Ending (new files)", selection: $defaultLineEnding) {
                ForEach(LineEndingPreference.allCases) { ending in
                    Text(ending.displayName).tag(ending.rawValue)
                }
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
