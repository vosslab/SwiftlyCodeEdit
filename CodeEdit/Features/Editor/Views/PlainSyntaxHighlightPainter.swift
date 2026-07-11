//
//  PlainSyntaxHighlightPainter.swift
//  CodeEdit
//
//  Created by Codex on 2026-07-07.
//

import AppKit
import Foundation
import CodeEditHighlighting
import CodeEditTextView

// Applies resolved spans to an NSTextStorage as foreground-color attributes,
// resolving the live theme variant each pass. The full-document paint carries
// the SETTINGS_APPLIED key=theme marker (load-bearing for the Settings smoke
// gate) and the milestone token summary; the bounded paint colors just an
// edited region.
@MainActor
enum HighlightPainter {
    // Whether the editor should use the dark theme variant, resolved from the
    // running app's effective appearance. NSApp is an implicitly-unwrapped
    // optional that is nil before an NSApplication exists (for example a headless
    // unit test that highlights a bare NSTextStorage), so this resolves to the
    // light variant rather than crashing when there is no app.
    static func isDarkAppearance() -> Bool {
        guard let app = NSApp else { return false }
        return app.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    static func applyHighlight(
        spans: [HighlightSpan],
        storage: NSTextStorage,
        text: String,
        languageName: String,
        layoutTarget: TextView?,
        elapsedMilliseconds: Int,
        state: HighlightState
    ) {
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }
        // Reads the Settings scene's live theme choice. This function
        // runs on every highlight pass, including the cache-hit fast path, so
        // a theme switch takes effect on the very next pass without a fresh
        // span computation.
        let theme = ThemeRepository.resolvedTheme(named: PlainEditorSettingsKeys.currentThemeName())
        // Detect the theme-name change here, but log the marker only after the
        // colors below are actually applied to the storage and laid out, so
        // SETTINGS_APPLIED key=theme reports a real rendered-state change, not
        // just the resolve.
        let themeNameChanged = theme.name != state.lastAppliedThemeName
        let variant = theme.variant(forDarkAppearance: isDarkAppearance())
        #if DEBUG
        let summary = Dictionary(grouping: spans, by: \.token).mapValues(\.count)
        let styles = Dictionary(grouping: spans.compactMap(\.styleName), by: { $0 }).mapValues(\.count)
        let samples = spans.prefix(12).map { span -> String in
            let range = NSRange(span.range, in: text)
            let snippet = (Range(range, in: text).map { String(text[$0]) } ?? "").replacingOccurrences(of: "\n", with: "\\n")
            return "\(span.styleName ?? String(describing: span.token)):\(snippet)"
        }.joined(separator: " | ")
        var finishLog = "PlainSyntaxHighlighter finish language=\(languageName) theme=\(theme.name)"
        finishLog += " spans=\(spans.count) elapsedMs=\(elapsedMilliseconds)"
        finishLog += " tokens=\(summary) styles=\(styles) samples=[\(samples)]"
        debugRuntimeLog(finishLog)
        #endif
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.foregroundColor, value: variant.baseText.toNSColor(), range: fullRange)
        apply(spans: spans, storage: storage, text: text, variant: variant)
        layout(layoutTarget)
        // The colors are now on the storage and laid out; this is the point
        // after which the editor's rendered state has actually changed, so log
        // the theme marker here rather than at the resolve above.
        if themeNameChanged {
            state.lastAppliedThemeName = theme.name
            debugRuntimeLog("SETTINGS_APPLIED key=theme")
        }
        #if DEBUG
        logMilestoneSyntaxSummary(spans: spans)
        #endif
    }

    // Applies base-text and span colors over just `region`. The spans carry
    // region-local UTF-16 offsets (they were interpreted from the region
    // substring), so each is shifted by the region start to reach document
    // coordinates. Attributes outside the region are left untouched; NSTextStorage
    // already shifted them to follow the edit.
    static func applyBoundedHighlight(
        spans: [HighlightSpan],
        storage: NSTextStorage,
        region: NSRange,
        layoutTarget: TextView?
    ) {
        let fullLength = storage.length
        let clampedLocation = min(max(region.location, 0), fullLength)
        let clampedLength = min(region.length, fullLength - clampedLocation)
        guard clampedLength > 0 else { return }
        let regionEnd = clampedLocation + clampedLength

        let theme = ThemeRepository.resolvedTheme(named: PlainEditorSettingsKeys.currentThemeName())
        let variant = theme.variant(forDarkAppearance: isDarkAppearance())

        let regionRange = NSRange(location: clampedLocation, length: clampedLength)
        storage.removeAttribute(.foregroundColor, range: regionRange)
        storage.addAttribute(.foregroundColor, value: variant.baseText.toNSColor(), range: regionRange)
        for span in spans {
            guard let localRange = span.nsRange else { continue }
            let documentLocation = clampedLocation + localRange.location
            let documentEnd = documentLocation + localRange.length
            // A span whose shifted range would leave the region (only possible
            // if the region was clamped shorter than the substring) is skipped
            // rather than painted out of bounds.
            guard documentLocation >= clampedLocation, documentEnd <= regionEnd else { continue }
            let color = variant.color(forToken: span.token, styleName: span.styleName).toNSColor()
            storage.addAttribute(
                .foregroundColor,
                value: color,
                range: NSRange(location: documentLocation, length: localRange.length)
            )
        }
        layout(layoutTarget)
    }

    private static func apply(spans: [HighlightSpan], storage: NSTextStorage, text: String, variant: ThemeVariant) {
        for span in spans {
            // Pipeline spans carry UTF-16 offsets from the interpreter, so apply
            // uses them directly and skips the per-span String.Index -> NSRange
            // conversion walk. The fallback covers spans built without offsets.
            let range = span.nsRange ?? NSRange(span.range, in: text)
            let color = variant.color(forToken: span.token, styleName: span.styleName).toNSColor()
            storage.addAttribute(.foregroundColor, value: color, range: range)
        }
    }

    // Re-lays and redisplays the text view after an attribute change. Foreground
    // color does not affect layout geometry, but laying out the visible lines
    // keeps the TextView's rendering pipeline in step and stays bounded to the
    // viewport.
    private static func layout(_ layoutTarget: TextView?) {
        guard let layoutTarget else { return }
        layoutTarget.layoutManager.setNeedsLayout()
        layoutTarget.layoutManager.layoutLines()
        layoutTarget.needsDisplay = true
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
        if milestoneTokens.allSatisfy({ tokens.contains($0) }) {
            HighlightStateStore.didLogSmokeTokenSummary = true
        }
    }
    #endif
}
