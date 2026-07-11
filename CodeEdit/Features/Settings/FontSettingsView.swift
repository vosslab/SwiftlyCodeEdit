//
//  FontSettingsView.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-10.
//

import SwiftUI

/// The Settings scene's "General" pane: static font family and size controls
/// that persist to the same `PlainEditor.fontFamily` / `PlainEditor.fontSize`
/// `@AppStorage` keys the Format menu's Increase/Decrease/Reset Size items
/// already write in `CodeFileView.swift`. Because both readers use `@AppStorage` on
/// the same key, a change made here is picked up by every already-open
/// document window's `CodeFileView` without relaunching: SwiftUI re-renders
/// any view holding that key, `editorFont` recomputes, and
/// `PlainTextEditorView.updateNSViewController` applies the new `NSFont` to
/// the live `TextView` (the log site for `SETTINGS_APPLIED key=fontFamily`
/// and `SETTINGS_APPLIED key=fontSize`).
struct FontSettingsView: View {
    @AppStorage("PlainEditor.fontFamily")
    private var fontFamily = PlainEditorFontSettings.defaultFontFamily
    @AppStorage("PlainEditor.fontSize")
    private var fontSize = PlainEditorFontSettings.defaultFontSize

    var body: some View {
        Form {
            Picker("Font Family", selection: $fontFamily) {
                ForEach(PlainEditorFontSettings.availableFontFamilies, id: \.self) { family in
                    Text(family).tag(family)
                }
            }

            Stepper(
                "Font Size: \(Int(fontSize.rounded())) pt",
                value: $fontSize,
                in: PlainEditorFontSettings.minimumFontSize...PlainEditorFontSettings.maximumFontSize,
                step: 1
            )

            Button("Reset to Defaults") {
                fontFamily = PlainEditorFontSettings.defaultFontFamily
                fontSize = PlainEditorFontSettings.defaultFontSize
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
