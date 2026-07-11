//
//  PlainEditorAppearanceMarkerTests.swift
//  CodeEditTests
//
//  Covers the pure override-resolution and line-formatting half of the
//  appearance/accessibility marker. The live NSApp/NSWorkspace read half needs
//  a running AppKit application and is proven end to end by the smoke script.
//

#if DEBUG
import Foundation
import Testing
@testable import CodeEdit

@Suite
struct PlainEditorAppearanceMarkerTests {
    @Test
    func overrideBoolIsNilWhenKeyAbsent() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let result = PlainEditorAppearanceMarker.overrideBool(
            forKey: PlainEditorAppearanceMarker.forceReduceTransparencyKey, in: defaults
        )

        #expect(result == nil)
    }

    @Test
    func overrideBoolReadsExplicitFalse() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: PlainEditorAppearanceMarker.forceIncreaseContrastKey)

        let result = PlainEditorAppearanceMarker.overrideBool(
            forKey: PlainEditorAppearanceMarker.forceIncreaseContrastKey, in: defaults
        )

        #expect(result == false)
    }

    @Test
    func overrideBoolReadsExplicitTrue() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(true, forKey: PlainEditorAppearanceMarker.forceIncreaseContrastKey)

        let result = PlainEditorAppearanceMarker.overrideBool(
            forKey: PlainEditorAppearanceMarker.forceIncreaseContrastKey, in: defaults
        )

        #expect(result == true)
    }

    @Test
    func effectiveFlagPrefersOverrideOverSystemValue() {
        #expect(PlainEditorAppearanceMarker.effectiveFlag(override: true, systemValue: false) == true)
        #expect(PlainEditorAppearanceMarker.effectiveFlag(override: false, systemValue: true) == false)
    }

    @Test
    func effectiveFlagFallsBackToSystemValueWhenNoOverride() {
        #expect(PlainEditorAppearanceMarker.effectiveFlag(override: nil, systemValue: true) == true)
        #expect(PlainEditorAppearanceMarker.effectiveFlag(override: nil, systemValue: false) == false)
    }

    @Test
    func overrideAppearanceModeIsNilWhenKeyAbsent() {
        let result = PlainEditorAppearanceMarker.overrideAppearanceMode(in: [:])

        #expect(result == nil)
    }

    @Test
    func overrideAppearanceModeReadsLightAndDarkCaseInsensitively() {
        let light = [PlainEditorAppearanceMarker.forceAppearanceKey: "Light"]
        #expect(PlainEditorAppearanceMarker.overrideAppearanceMode(in: light) == "light")

        let dark = [PlainEditorAppearanceMarker.forceAppearanceKey: "DARK"]
        #expect(PlainEditorAppearanceMarker.overrideAppearanceMode(in: dark) == "dark")
    }

    @Test
    func overrideAppearanceModeIsNilForUnrecognizedValue() {
        let argumentDomain = [PlainEditorAppearanceMarker.forceAppearanceKey: "Blue"]

        let result = PlainEditorAppearanceMarker.overrideAppearanceMode(in: argumentDomain)

        #expect(result == nil)
    }

    @Test
    func markerLineFormatsModeAndBothFlags() {
        let line = PlainEditorAppearanceMarker.markerLine(
            mode: "dark", reduceTransparency: true, increaseContrast: false
        )

        #expect(line == "APPEARANCE_MODE=dark reduceTransparency=1 increaseContrast=0")
    }
}
#endif
