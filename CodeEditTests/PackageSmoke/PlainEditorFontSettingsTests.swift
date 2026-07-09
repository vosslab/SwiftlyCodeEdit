//
//  PlainEditorFontSettingsTests.swift
//  CodeEditTests
//
//  Created by Codex on 2026-07-07.
//

import AppKit
import Testing
@testable import CodeEdit

@Suite
struct PlainEditorFontSettingsTests {
    @Test
    func defaultFontIsMonospace() {
        let font = PlainEditorFontSettings.font(
            family: PlainEditorFontSettings.defaultFontFamily,
            size: PlainEditorFontSettings.defaultFontSize
        )

        #expect(font.isFixedPitch)
        #expect(isSamePointSize(font.pointSize, PlainEditorFontSettings.defaultFontSize))
    }

    @Test
    func unavailableFontFallsBackToMonospace() {
        let font = PlainEditorFontSettings.font(family: "Definitely Not A Font", size: 15)

        #expect(font.isFixedPitch)
        #expect(font.pointSize == 15)
    }

    @Test
    func fontSizeIsClampedToUsableRange() {
        let small = PlainEditorFontSettings.font(family: PlainEditorFontSettings.defaultFontFamily, size: 1)
        let large = PlainEditorFontSettings.font(family: PlainEditorFontSettings.defaultFontFamily, size: 100)

        #expect(isSamePointSize(small.pointSize, PlainEditorFontSettings.minimumFontSize))
        #expect(isSamePointSize(large.pointSize, PlainEditorFontSettings.maximumFontSize))
    }

    private func isSamePointSize(_ lhs: CGFloat, _ rhs: Double) -> Bool {
        abs(Double(lhs) - rhs) < 0.01
    }
}
