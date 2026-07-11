//
//  PlainEditorSettingsKeys.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-10.
//

import Foundation

/// UserDefaults key names backing the Settings scene and the
/// enumerations for its two picker-backed preferences (indentation style and
/// default line ending). Both the SwiftUI Settings views and any plain-Swift
/// reader (`PlainSyntaxHighlighter`, which is not a `View` and cannot use
/// `@AppStorage`) share these string constants, so a key never drifts between
/// the writer and the reader.
///
/// Font family and size reuse the pre-existing `PlainEditor.fontFamily` /
/// `PlainEditor.fontSize` keys already written by the Format menu's
/// Increase/Decrease/Reset Size items (`EditorCommands.swift`); this type
/// does not redeclare those two.
enum PlainEditorSettingsKeys {
    static let themeName = "PlainEditor.themeName"
    static let indentationStyle = "PlainEditor.indentationStyle"
    static let indentationWidth = "PlainEditor.indentationWidth"
    static let defaultLineEnding = "PlainEditor.defaultLineEnding"

    /// The active theme's schema `name`, read directly from `UserDefaults`
    /// rather than through `@AppStorage`. `PlainSyntaxHighlighter` is a plain
    /// `enum`, not a SwiftUI `View`, so it cannot hold an `@AppStorage`
    /// property wrapper; reading the same key it was written under keeps the
    /// highlighter's theme selection in sync with the Settings picker without
    /// threading a theme name through every `highlight(...)` call site.
    static func currentThemeName() -> String {
        UserDefaults.standard.string(forKey: themeName) ?? ThemeRepository.bundledDefaultThemeName
    }
}

/// Indentation style preference, persisted as its `rawValue` under
/// `PlainEditorSettingsKeys.indentationStyle`. Consumption by the editor
/// (auto-indent on Return, Tab-key behavior) lands with the document-side
/// packages; the Settings scene only persists and exposes the setting.
enum IndentationStyle: String, CaseIterable, Identifiable {
    case spaces
    case tabs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spaces: "Spaces"
        case .tabs: "Tabs"
        }
    }
}

/// Default line-ending preference for newly created documents, persisted as
/// its `rawValue` under `PlainEditorSettingsKeys.defaultLineEnding`. Per the
/// plan's Resolved decisions, new files default to LF. Consumption by
/// document creation lands with the document-side packages; the Settings
/// scene only persists and exposes the setting.
enum LineEndingPreference: String, CaseIterable, Identifiable {
    case lf
    case crlf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lf: "LF (Unix)"
        case .crlf: "CRLF (Windows)"
        }
    }
}
