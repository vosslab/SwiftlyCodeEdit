//
//  PlainEditorSettingsApplySelfTest.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-10.
//

#if DEBUG
import AppKit
import Foundation

/// DEBUG-only live-apply self-test for the Settings scene. Gated by the
/// `CODEEDIT_SETTINGS_APPLY_SELF_TEST=1` environment variable and scheduled from
/// `CodeFileView.onTextViewReady` (mirroring `PlainEditorCommandSelfTest`), it
/// proves the `SETTINGS_APPLIED` markers fire from a genuine post-mount change
/// through the same code path the Settings window uses.
///
/// Why this exists: a cold launch seeded through `NSArgumentDomain` cannot fire
/// the markers -- `PlainTextEditorView.makeNSViewController` and its first
/// `updateNSViewController` read the same `@AppStorage` font value, so the font
/// comparison never differs on creation; and with one bundled theme every
/// requested name resolves to `standard`, so the theme name never changes. This
/// self-test instead performs a real change AFTER the window is mounted and the
/// first highlight pass has settled.
///
/// Persistence discipline: the Settings scene writes its preferences through
/// `@AppStorage`, which is backed by `UserDefaults.standard`, so this self-test
/// drives its changes the same way. It captures each key's prior value
/// (including absence), applies a distinct value, then restores the captured
/// value -- leaving the user's stored preferences untouched after the run. The
/// distinct theme is a DEBUG in-memory theme (`ThemeRepository`), never a file
/// written into the user's Themes directory.
@MainActor
enum PlainEditorSettingsApplySelfTest {
    private static var didSchedule = false
    private static let selfTestThemeName = "settings-apply-self-test-theme"
    private static let fontSizeKey = "PlainEditor.fontSize"

    static func scheduleIfRequested() {
        guard ProcessInfo.processInfo.environment["CODEEDIT_SETTINGS_APPLY_SELF_TEST"] == "1",
              !didSchedule else {
            return
        }
        didSchedule = true

        // Wait past the first highlight pass and initial layout so the values
        // the self-test toggles against are the settled launch state, not a
        // font or theme still mid-apply. The command self-test (when also
        // requested) runs at +0.5 s and restores its text synchronously, so
        // this +1.0 s start never overlaps it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            applyChanges()
        }
    }

    // Applies a distinct font size and theme through UserDefaults.standard (the
    // @AppStorage-backed store), so every open CodeFileView re-renders: the new
    // font reaches PlainTextEditorView.updateNSViewController (font marker) and
    // the new theme name reaches PlainSyntaxHighlighter.applyHighlight through
    // CodeFileView's onChange(of:) (theme marker).
    private static func applyChanges() {
        let defaults = UserDefaults.standard
        let themeKey = PlainEditorSettingsKeys.themeName

        // Capture prior state INCLUDING absence so the restore below removes a
        // key that was absent rather than leaving a value behind.
        let originalFontSizeObject = defaults.object(forKey: fontSizeKey)
        let originalThemeObject = defaults.object(forKey: themeKey)

        let currentFontSize = originalFontSizeObject as? Double ?? PlainEditorFontSettings.defaultFontSize
        let targetFontSize = nextDistinctFontSize(from: currentFontSize)

        // Register a distinctly-named in-memory theme (same colors as the
        // bundled default, different name) so a genuine theme-name change is
        // resolvable with only one bundled theme and zero persistence.
        ThemeRepository.registerInMemoryTheme(makeSelfTestTheme())

        defaults.set(targetFontSize, forKey: fontSizeKey)
        defaults.set(selfTestThemeName, forKey: themeKey)

        // Give the markers a run-loop turn to fire, then restore through the
        // same live path so the self-test also proves reversal.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            restore(originalFontSizeObject: originalFontSizeObject, originalThemeObject: originalThemeObject)
        }
    }

    private static func restore(originalFontSizeObject: Any?, originalThemeObject: Any?) {
        let defaults = UserDefaults.standard
        let themeKey = PlainEditorSettingsKeys.themeName

        restoreDefault(defaults, key: fontSizeKey, original: originalFontSizeObject)
        restoreDefault(defaults, key: themeKey, original: originalThemeObject)
        ThemeRepository.clearInMemoryThemes()

        // Confirm the store now matches the captured originals, so a green run
        // also proves the seam persisted nothing to the user's preferences.
        let fontRestored = objectsEqual(defaults.object(forKey: fontSizeKey), originalFontSizeObject)
        let themeRestored = objectsEqual(defaults.object(forKey: themeKey), originalThemeObject)
        debugRuntimeLog("SETTINGS_APPLY_SELF_TEST fontRestored=\(fontRestored) themeRestored=\(themeRestored)")
    }

    // Restores one key to its captured prior value, or removes it when it was
    // absent before the run.
    private static func restoreDefault(_ defaults: UserDefaults, key: String, original: Any?) {
        if let original {
            defaults.set(original, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    // Picks a font size that is guaranteed to differ in pointSize from the
    // current one while staying inside the editor's clamp range, so the
    // view-application comparison in PlainTextEditorView always sees a change.
    private static func nextDistinctFontSize(from current: Double) -> Double {
        if current >= PlainEditorFontSettings.maximumFontSize - 1 {
            return current - 2
        }
        return current + 2
    }

    // A distinctly-named copy of the bundled default theme. Real colors keep
    // highlighting working; the different name is what makes the theme marker
    // fire (it keys on the resolved theme's name).
    private static func makeSelfTestTheme() -> SyntaxTheme {
        let base = ThemeRepository.bundledDefaultTheme()
        // base always carries at least one variant (it is the shipped theme or
        // the emergency fallback), so this initializer never fails.
        return SyntaxTheme(
            version: base.version,
            name: selfTestThemeName,
            light: base.light,
            dark: base.dark
        )! // swiftlint:disable:this force_unwrapping
    }

    // Compares two UserDefaults values (or their absence) for equality. The
    // values here are a Double (NSNumber) and a String (NSString), both of
    // which bridge to NSObject and answer isEqual correctly.
    private static func objectsEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return (left as? NSObject)?.isEqual(right) ?? false
        default:
            return false
        }
    }
}
#endif
