//
//  PlainEditorAppearanceMarker.swift
//  CodeEdit
//
//  DEBUG-only appearance/accessibility runtime marker. Holds the
//  AppKit-free half: the launch-argument override keys, override resolution,
//  and marker-line formatting. The live NSApp.effectiveAppearance and
//  NSWorkspace accessibility reads live in the sanctioned document-layer
//  bridge (CodeFileDocumentBridge.swift), the only place those AppKit symbols
//  are permitted for this seam.
//

#if DEBUG
import Foundation

/// AppKit-free helpers for the appearance/accessibility marker. Kept separate
/// from the live NSApp/NSWorkspace reads so the override-argument parsing and
/// line formatting are unit-testable without a running AppKit application.
enum PlainEditorAppearanceMarker {
    /// Launch-argument keys. Passing `-PlainEditor.forceReduceTransparency YES`
    /// or `-PlainEditor.forceIncreaseContrast YES` lands in UserDefaults'
    /// volatile NSArgumentDomain (per-process, never persisted), so a smoke
    /// run can force the accessibility state this marker reports without
    /// touching the real systemwide `com.apple.universalaccess` preferences.
    static let forceReduceTransparencyKey = "PlainEditor.forceReduceTransparency"
    static let forceIncreaseContrastKey = "PlainEditor.forceIncreaseContrast"

    /// Forces the app's effective appearance. Reuses the launch
    /// argument macOS already recognizes for interface style, so
    /// "-AppleInterfaceStyle Light|Dark" flips NSApp.effectiveAppearance for
    /// this process alone, landing in UserDefaults' volatile NSArgumentDomain
    /// the same as the flags above (never persisted, no `defaults write`).
    static let forceAppearanceKey = "AppleInterfaceStyle"

    /// Reads an override key from `defaults`, returning nil when the key is
    /// absent so the caller can tell "argument not passed" apart from
    /// "argument passed as false".
    static func overrideBool(forKey key: String, in defaults: UserDefaults) -> Bool? {
        guard defaults.object(forKey: key) != nil else {
            return nil
        }
        return defaults.bool(forKey: key)
    }

    /// Reads the forced-appearance launch argument, returning "light" or
    /// "dark" (case-insensitive), or nil when the argument is absent or
    /// holds a value other than those two. Takes the NSArgumentDomain
    /// dictionary directly (not a merged UserDefaults instance): macOS
    /// itself stores the real system Dark Mode state under this very same
    /// "AppleInterfaceStyle" key in NSGlobalDomain, which sits later in
    /// every UserDefaults search list, so reading through the merged search
    /// list would make an ordinary launch on a dark-mode Mac silently force
    /// dark even with no launch argument present. Pass
    /// `UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)`
    /// from the AppKit call site to see only genuine launch arguments.
    static func overrideAppearanceMode(in argumentDomain: [String: Any]) -> String? {
        guard let value = argumentDomain[forceAppearanceKey] as? String else {
            return nil
        }
        switch value.lowercased() {
        case "dark":
            return "dark"
        case "light":
            return "light"
        default:
            return nil
        }
    }

    /// Resolves the effective flag the marker should report: an explicit
    /// launch-argument override when present, otherwise the real system
    /// value read from NSWorkspace.
    static func effectiveFlag(override overrideValue: Bool?, systemValue: Bool) -> Bool {
        overrideValue ?? systemValue
    }

    /// Formats the single runtime-log marker line, for example
    /// "APPEARANCE_MODE=dark reduceTransparency=1 increaseContrast=0".
    static func markerLine(mode: String, reduceTransparency: Bool, increaseContrast: Bool) -> String {
        "APPEARANCE_MODE=\(mode) reduceTransparency=\(reduceTransparency ? 1 : 0) "
        + "increaseContrast=\(increaseContrast ? 1 : 0)"
    }
}
#endif
