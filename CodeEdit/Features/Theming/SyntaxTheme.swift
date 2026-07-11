//
//  SyntaxTheme.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-09.
//

import CodeEditHighlighting
import Foundation

/// One variant (light or dark) of a parsed theme: the flat token/style color
/// mapping described by docs/THEME_FORMAT.md. `Sendable` so a background
/// parse task can hand a finished theme back to the main actor without a
/// warning.
struct ThemeVariant: Sendable, Equatable {
    let baseText: ThemeColor
    let background: ThemeColor
    let tokens: [HighlightToken: ThemeColor]
    let styles: [String: ThemeColor]

    /// Resolution order per docs/THEME_FORMAT.md: style key, then token key,
    /// then `base_text`. This ports `PlainSyntaxTheme.color(for:)` unchanged.
    func color(forToken token: HighlightToken, styleName: String?) -> ThemeColor {
        if let styleName, let styleColor = styles[styleName.lowercased()] {
            return styleColor
        }
        if let tokenColor = tokens[token] {
            return tokenColor
        }
        return baseText
    }
}

/// A fully parsed theme file: a schema `name`, and one or both appearance
/// variants. `Sendable` so theme parsing can run off the main actor.
struct SyntaxTheme: Sendable, Equatable {
    let version: Int
    let name: String
    let light: ThemeVariant?
    let dark: ThemeVariant?

    /// Fails only if neither variant is present; `ThemeParser` never builds a
    /// `SyntaxTheme` that violates this, so callers can treat `variant(forDark:)`
    /// as total.
    init?(version: Int, name: String, light: ThemeVariant?, dark: ThemeVariant?) {
        guard light != nil || dark != nil else { return nil }
        self.version = version
        self.name = name
        self.light = light
        self.dark = dark
    }

    /// Missing-variant fallback (docs/THEME_FORMAT.md rule 2): a theme that
    /// only defines one variant is used for both appearances rather than
    /// guessing colors for the missing one.
    func variant(forDarkAppearance isDark: Bool) -> ThemeVariant {
        if isDark {
            return dark ?? light! // swiftlint:disable:this force_unwrapping
        }
        return light ?? dark! // swiftlint:disable:this force_unwrapping
    }

    // Last-resort theme used only if the bundled `standard.yaml` resource
    // itself is unreadable or fails to parse (a corrupted app bundle).
    // Hardcoded here, rather than re-parsed from a duplicate string, because
    // this is the one path that must not depend on file I/O or parsing
    // succeeding at all; the hex values are the same ones `standard.yaml`
    // ships (see that file's header comment for how they were measured).
    static let emergencyFallbackTheme: SyntaxTheme = {
        let light = ThemeVariant(
            baseText: ThemeColor(hex: "#000000")!, // swiftlint:disable:this force_unwrapping
            background: ThemeColor(hex: "#FFFFFF")!, // swiftlint:disable:this force_unwrapping
            tokens: [:],
            styles: [:]
        )
        let dark = ThemeVariant(
            baseText: ThemeColor(hex: "#FFFFFF")!, // swiftlint:disable:this force_unwrapping
            background: ThemeColor(hex: "#1E1E1E")!, // swiftlint:disable:this force_unwrapping
            tokens: [:],
            styles: [:]
        )
        return SyntaxTheme(version: 1, name: "emergency_fallback", light: light, dark: dark)!
        // swiftlint:disable:previous force_unwrapping
    }()
}
