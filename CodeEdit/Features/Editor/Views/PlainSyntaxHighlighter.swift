//
//  PlainSyntaxHighlighter.swift
//  CodeEdit
//
//  Created by Codex on 2026-07-07.
//

import AppKit
import Foundation
import CodeEditHighlighting
import CodeEditLanguages
import CodeEditSyntaxDefinitions

enum PlainSyntaxHighlighter {
    static func highlight(storage: NSTextStorage, language: CodeLanguage) {
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        let text = storage.string
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let definitionSummary = CodeEditSyntaxDefinitions.debugSummary(language: language.tsName)
        debugRuntimeLog("PlainSyntaxHighlighter start language=\(language.tsName) length=\(storage.length) \(definitionSummary)")
        #endif
        let spans = CodeEditSyntaxDefinitions.highlightSpans(text: text, language: language.tsName)
        let theme = PlainSyntaxTheme.current
        #if DEBUG
        let elapsedMilliseconds = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        let summary = Dictionary(grouping: spans, by: \.token).mapValues(\.count)
        let styles = Dictionary(grouping: spans.compactMap(\.styleName), by: { $0 }).mapValues(\.count)
        let samples = spans.prefix(12).map { span -> String in
            let range = NSRange(span.range, in: text)
            let snippet = (Range(range, in: text).map { String(text[$0]) } ?? "").replacingOccurrences(of: "\n", with: "\\n")
            return "\(span.styleName ?? String(describing: span.token)):\(snippet)"
        }.joined(separator: " | ")
        debugRuntimeLog("PlainSyntaxHighlighter finish language=\(language.tsName) theme=\(theme.name) spans=\(spans.count) elapsedMs=\(elapsedMilliseconds) tokens=\(summary) styles=\(styles) samples=[\(samples)]")
        #endif
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.foregroundColor, value: theme.baseTextColor, range: fullRange)
        apply(spans: spans, storage: storage, text: text, theme: theme)
        #if DEBUG
        logMilestoneSyntaxSummary(spans: spans)
        #endif
    }

    private static func apply(spans: [HighlightSpan], storage: NSTextStorage, text: String, theme: PlainSyntaxTheme) {
        for span in spans {
            let range = NSRange(span.range, in: text)
            storage.addAttribute(.foregroundColor, value: theme.color(for: span), range: range)
        }
    }

    #if DEBUG
    private static func logMilestoneSyntaxSummary(spans: [HighlightSpan]) {
        let milestoneTokens: [HighlightToken] = [.comment, .keyword, .number, .string, .type]
        let tokens = Set(spans.map(\.token))
        let tokenNames = milestoneTokens
            .filter { tokens.contains($0) }
            .map(String.init(describing:))
            .joined(separator: ",")
        debugRuntimeLog("Plain editor Swift syntax highlight: tokens=\(tokenNames) colors=6")
    }
    #endif
}

private struct PlainSyntaxTheme {
    let name: String
    let baseTextColor: NSColor
    let tokenColors: [HighlightToken: NSColor]
    let styleColors: [String: NSColor]

    static var current: PlainSyntaxTheme {
        if ProcessInfo.processInfo.environment["SYNTAX_THEME_VARIANT"] == "rotated" {
            return rotated
        }
        return standard
    }

    static let standard = PlainSyntaxTheme(
        name: "standard",
        baseTextColor: .textColor,
        tokenColors: [
            .comment: .systemGreen,
            .keyword: .systemBlue,
            .string: .systemRed,
            .number: .systemPurple,
            .function: .systemOrange,
            .type: .systemTeal,
            .operatorToken: .secondaryLabelColor,
            .markup: .systemPink,
            .plainText: .textColor
        ],
        styleColors: [
            "imports": .systemTeal,
            "variable": .textColor,
            "data type": .systemTeal,
            "function": .systemOrange,
            "annotation": .systemPurple,
            "string interpolation": .systemOrange
        ]
    )

    static let rotated = PlainSyntaxTheme(
        name: "rotated",
        baseTextColor: .textColor,
        tokenColors: [
            .comment: .systemOrange,
            .keyword: .systemPink,
            .string: .systemBlue,
            .number: .systemGreen,
            .function: .systemPurple,
            .type: .systemBrown,
            .operatorToken: .systemMint,
            .markup: .systemRed,
            .plainText: .textColor
        ],
        styleColors: [
            "imports": .systemBrown,
            "variable": .textColor,
            "data type": .systemBrown,
            "function": .systemPurple,
            "annotation": .systemGreen,
            "string interpolation": .systemPink
        ]
    )

    func color(for span: HighlightSpan) -> NSColor {
        if let styleName = span.styleName?.lowercased(), let color = styleColors[styleName] {
            return color
        }
        return tokenColors[span.token] ?? baseTextColor
    }
}
