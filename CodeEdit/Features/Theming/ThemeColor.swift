//
//  ThemeColor.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-09.
//

import AppKit
import Foundation

/// A parsed theme color, stored as plain RGBA components so the type stays a
/// trivially `Sendable` value (`NSColor` itself is not a `Sendable` type, so
/// theme parsing -- which must run off the main actor -- never
/// carries one across a task boundary).
struct ThemeColor: Sendable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    /// Parses `#RRGGBB` or `#RRGGBBAA` per docs/THEME_FORMAT.md's color value
    /// syntax. Returns nil for anything else (named colors, other color
    /// spaces, wrong digit counts), which the caller treats as a missing key.
    init?(hex: String) {
        var digits = hex
        guard digits.hasPrefix("#") else { return nil }
        digits.removeFirst()
        guard digits.count == 6 || digits.count == 8 else { return nil }
        guard let value = UInt32(digits, radix: 16) else { return nil }

        let hasAlpha = digits.count == 8
        let redByte: UInt32
        let greenByte: UInt32
        let blueByte: UInt32
        let alphaByte: UInt32
        if hasAlpha {
            redByte = (value >> 24) & 0xFF
            greenByte = (value >> 16) & 0xFF
            blueByte = (value >> 8) & 0xFF
            alphaByte = value & 0xFF
        } else {
            redByte = (value >> 16) & 0xFF
            greenByte = (value >> 8) & 0xFF
            blueByte = value & 0xFF
            alphaByte = 0xFF
        }

        self.red = Double(redByte) / 255.0
        self.green = Double(greenByte) / 255.0
        self.blue = Double(blueByte) / 255.0
        self.alpha = Double(alphaByte) / 255.0
    }

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Converts to the AppKit color the highlighter applies as an attribute.
    /// `NSColor(srgbRed:...)` is safe to call from any thread; only the
    /// resulting attribute application to `NSTextStorage` is main-actor work.
    func toNSColor() -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
