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
import CodeEditTextView

@MainActor
enum PlainSyntaxHighlighter {
    // Per-document highlight state. Every NSTextStorage (one per open document
    // window) owns its own generation counter and span cache, so one window's
    // request can never invalidate another window's in-flight compute. A single
    // shared static counter would let window B's request bump the generation and
    // strand window A's ~6 s cold result at the post-compute guard.
    private final class HighlightState {
        var cachedLanguage = ""
        var cachedText = ""
        var cachedSpans: [HighlightSpan] = []
        // Monotonic request token for THIS storage. Every request captures the
        // current value; a background result whose token no longer matches is
        // stale (a newer request for this same storage superseded it).
        var latestGeneration = 0
    }

    // Weak-to-strong with POINTER identity keys: the key (storage) is held
    // weakly, so when a document window closes and its storage deallocs, the
    // entry is dropped automatically and the state does not leak; auto-cleanup
    // also avoids the ObjectIdentifier address-reuse hazard of a plain
    // dictionary. `.objectPointerPersonality` is essential: NSTextStorage is an
    // NSMutableAttributedString, which implements content-based hash/isEqual, so
    // the default object personality would rehash a storage on every edit and
    // lose its state (resetting the per-document generation on each keystroke).
    // Pointer personality keys on object identity, which is stable across edits.
    private static let states = NSMapTable<NSTextStorage, HighlightState>(
        keyOptions: [.weakMemory, .objectPointerPersonality],
        valueOptions: [.strongMemory],
        capacity: 4
    )

    private static func state(for storage: NSTextStorage) -> HighlightState {
        if let existing = states.object(forKey: storage) {
            return existing
        }
        let created = HighlightState()
        states.setObject(created, forKey: storage)
        return created
    }

    #if DEBUG
    private static var didLogSmokeTokenSummary = false
    #endif

    static func highlight(textView: TextView, language: CodeLanguage) {
        scheduleHighlight(storage: textView.textStorage, language: language, layoutTarget: textView)
    }

    static func highlight(storage: NSTextStorage, language: CodeLanguage) {
        scheduleHighlight(storage: storage, language: language, layoutTarget: nil)
    }

    // Span computation runs off the main thread; attribute application hops
    // back to @MainActor so the first window paints plain text immediately
    // instead of blocking window construction on the cold interpreter cost.
    private static func scheduleHighlight(
        storage: NSTextStorage,
        language: CodeLanguage,
        layoutTarget: TextView?
    ) {
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        let text = storage.string
        let languageName = language.tsName
        let state = state(for: storage)
        #if DEBUG
        if ProcessInfo.processInfo.environment["CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST"] == "1",
           didLogSmokeTokenSummary,
           text != state.cachedText {
            return
        }
        #endif

        // Fast path: an identical text+language was already computed for this
        // storage, so apply the cached spans synchronously without another pass.
        if state.cachedLanguage == languageName, state.cachedText == text {
            applyHighlight(
                spans: state.cachedSpans,
                storage: storage,
                text: text,
                languageName: languageName,
                layoutTarget: layoutTarget,
                elapsedMilliseconds: 0
            )
            return
        }

        state.latestGeneration += 1
        let requestGeneration = state.latestGeneration
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let definitionSummary = CodeEditSyntaxDefinitions.debugSummary(language: languageName)
        debugRuntimeLog("PlainSyntaxHighlighter start language=\(languageName) length=\(storage.length) \(definitionSummary)")
        #endif

        // The enclosing type is @MainActor, so this Task resumes on the main
        // actor; only the detached child runs the interpreter off-main. The task
        // captures `storage` strongly on purpose: the capture is bounded (the
        // task always returns once its generation is superseded or its result is
        // applied), so it keeps the storage alive only for the duration of one
        // pass rather than leaking it.
        Task {
            // Coalesce: a burst of edits enqueues many requests on the main
            // actor before any runs. Skip the expensive pass for every request
            // a newer one for this storage has already superseded.
            guard requestGeneration == state.latestGeneration else { return }

            // Bound the drift-recompute retries below. Each retry handles a
            // setString reload that changed the text without issuing a new
            // request; a pathological reload storm could otherwise spin here
            // indefinitely. After the cap we stop and let the next genuine
            // request repaint, which is strictly better than looping forever.
            var driftRetries = 0
            let maxDriftRetries = 8

            // Recompute against the current text until it stops drifting under
            // us, all under this single request's generation. A drift with no
            // new request happens when a presentedItemDidChange reload replaces
            // the text via setString, which never routes through a new highlight
            // request and so never bumps the generation; without this retry the
            // document would be left unhighlighted. A genuinely newer request
            // does bump the generation, which breaks the loop below so the newer
            // request wins instead of this one clobbering it. Each await frees
            // the main actor, so this never starves other work.
            var attemptText = text
            while true {
                let snapshot = attemptText
                let spans = await Task.detached(priority: .userInitiated) {
                    CodeEditSyntaxDefinitions.highlightSpans(text: snapshot, language: languageName)
                }.value

                // A newer request for THIS storage superseded us while we
                // computed; that request will apply its own result, so stop.
                guard requestGeneration == state.latestGeneration else {
                    #if DEBUG
                    debugRuntimeLog("PlainSyntaxHighlighter dropped superseded generation=\(requestGeneration) latest=\(state.latestGeneration)")
                    #endif
                    return
                }

                // Text drifted with no newer request (reload via setString).
                // Recompute against the current text rather than applying stale
                // spans or leaving the document unhighlighted.
                let currentText = storage.string
                guard currentText == snapshot else {
                    driftRetries += 1
                    guard driftRetries <= maxDriftRetries else {
                        #if DEBUG
                        debugRuntimeLog("PlainSyntaxHighlighter drift retry cap reached generation=\(requestGeneration) retries=\(driftRetries)")
                        #endif
                        return
                    }
                    #if DEBUG
                    debugRuntimeLog("PlainSyntaxHighlighter recomputing after text drift generation=\(requestGeneration) retry=\(driftRetries)")
                    #endif
                    attemptText = currentText
                    continue
                }

                state.cachedLanguage = languageName
                state.cachedText = snapshot
                state.cachedSpans = spans
                #if DEBUG
                let elapsedMilliseconds = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                #else
                let elapsedMilliseconds = 0
                #endif
                applyHighlight(
                    spans: spans,
                    storage: storage,
                    text: snapshot,
                    languageName: languageName,
                    layoutTarget: layoutTarget,
                    elapsedMilliseconds: elapsedMilliseconds
                )
                return
            }
        }
    }

    private static func applyHighlight(
        spans: [HighlightSpan],
        storage: NSTextStorage,
        text: String,
        languageName: String,
        layoutTarget: TextView?,
        elapsedMilliseconds: Int
    ) {
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }
        let theme = PlainSyntaxTheme.current
        #if DEBUG
        let summary = Dictionary(grouping: spans, by: \.token).mapValues(\.count)
        let styles = Dictionary(grouping: spans.compactMap(\.styleName), by: { $0 }).mapValues(\.count)
        let samples = spans.prefix(12).map { span -> String in
            let range = NSRange(span.range, in: text)
            let snippet = (Range(range, in: text).map { String(text[$0]) } ?? "").replacingOccurrences(of: "\n", with: "\\n")
            return "\(span.styleName ?? String(describing: span.token)):\(snippet)"
        }.joined(separator: " | ")
        debugRuntimeLog("PlainSyntaxHighlighter finish language=\(languageName) theme=\(theme.name) spans=\(spans.count) elapsedMs=\(elapsedMilliseconds) tokens=\(summary) styles=\(styles) samples=[\(samples)]")
        #endif
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.foregroundColor, value: theme.baseTextColor, range: fullRange)
        apply(spans: spans, storage: storage, text: text, theme: theme)
        if let layoutTarget {
            layoutTarget.layoutManager.setNeedsLayout()
            layoutTarget.layoutManager.layoutLines()
            layoutTarget.needsDisplay = true
        }
        #if DEBUG
        logMilestoneSyntaxSummary(spans: spans)
        #endif
    }

    private static func apply(spans: [HighlightSpan], storage: NSTextStorage, text: String, theme: PlainSyntaxTheme) {
        for span in spans {
            // Pipeline spans carry UTF-16 offsets from the interpreter, so apply
            // uses them directly and skips the per-span String.Index -> NSRange
            // conversion walk. The fallback covers spans built without offsets.
            let range = span.nsRange ?? NSRange(span.range, in: text)
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
        if milestoneTokens.allSatisfy({ tokens.contains($0) }) {
            didLogSmokeTokenSummary = true
        }
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
