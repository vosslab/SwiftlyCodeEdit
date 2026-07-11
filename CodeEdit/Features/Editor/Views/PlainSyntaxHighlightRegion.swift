//
//  PlainSyntaxHighlightRegion.swift
//  CodeEdit
//
//  Created for the bounded rehighlight pass.
//

import AppKit
import Foundation
import CodeEditTextView

// Plans the character region a bounded rehighlight pass reinterprets.
// The plain editor picks a small region around each edit and reinterprets only
// that region per keystroke, so a 1 MB file no longer pays a whole-document span
// compute and paint on every character. Two candidate strategies were prototyped
// and measured under the keystroke-latency harness; the edited-line-window
// strategy shipped (see test-results/perf/keystroke_latency_candidates.txt).
@MainActor
enum HighlightRegionPlanner {
    enum RehighlightStrategy {
        // Reinterpret the edited line(s) plus a fixed context window above and
        // below. Cost is independent of the viewport and of where in the document
        // the edit lands, so the edited text is always painted correctly.
        case editedLineWindow
        // Reinterpret the visible viewport. The caret scrolls into view on edit,
        // so the just-typed characters are normally repainted, but an edit that
        // lands off-screen (a scripted or multi-cursor mutation) stays stale until
        // scrolled into view, and coloring depends on where the viewport sits
        // rather than on where the edit is. That correctness cost is why the
        // edited-line-window strategy ships instead.
        case visibleRange
    }

    // Number of context lines included on each side of the edited line(s) for the
    // edited-line-window strategy. A window rather than a single line so an edit
    // that opens or closes a construct (a brace, a string quote, a comment start)
    // still repaints the immediately neighboring lines whose coloring can depend
    // on it. The Kate interpreter is stateful (its context stack depends on all
    // preceding text), so a bounded region that begins inside a long multi-line
    // string or comment can mis-color its head; the window is a pragmatic
    // mitigation, and the dirty-range contract in docs/CODE_ARCHITECTURE.md
    // records the limitation.
    static let editedWindowContextLines = 40

    // Below this document length the whole buffer is cheap enough to interpret in
    // one pass, so bounded scheduling adds no value and the well-tested full path
    // runs instead. The keystroke-latency fixture (~1 MB) is far above this.
    static let boundedMinimumDocumentLength = 20_000

    // On cold open of a document at least this large, the full path paints the
    // viewport region first (so the user sees colored text immediately) before
    // interpreting the whole document in the background.
    static let viewportFirstMinimumDocumentLength = 20_000

    // The active bounded-rehighlight strategy. Ships as edited-line-window (the
    // measured winner). A DEBUG environment override lets the keystroke-latency
    // harness measure the losing candidate without a rebuild; production always
    // uses the shipped default.
    static var activeStrategy: RehighlightStrategy {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["CODEEDIT_HIGHLIGHT_STRATEGY"] {
        case "visible":
            return .visibleRange
        case "edited":
            return .editedLineWindow
        default:
            break
        }
        #endif
        return .editedLineWindow
    }

    // Resolves the region to reinterpret for a bounded pass. Both strategies
    // return a range aligned to whole lines so a rule anchored at a line start
    // still matches, and both always cover the edited span so the just-typed
    // characters are repainted.
    static func boundedRegion(
        storage: NSTextStorage,
        editedSpan: NSRange,
        layoutTarget: TextView?,
        strategy: RehighlightStrategy
    ) -> NSRange {
        let editedWindow = editedLineWindowRegion(storage: storage, editedSpan: editedSpan)
        switch strategy {
        case .editedLineWindow:
            return editedWindow
        case .visibleRange:
            // Literal viewport region; falls back to the edited-line window only
            // when nothing is laid out yet (for example a storage-only pass with
            // no text view).
            guard let layoutTarget, let viewport = viewportRegion(layoutTarget: layoutTarget) else {
                return editedWindow
            }
            return viewport
        }
    }

    // Expands the edited span to whole lines, then walks `editedWindowContextLines`
    // additional lines above and below. Each `lineRange(for:)` call scans only
    // within the neighboring line, so this stays bounded by the window size, not
    // the document length.
    static func editedLineWindowRegion(storage: NSTextStorage, editedSpan: NSRange) -> NSRange {
        let nsString = storage.mutableString
        let fullLength = nsString.length
        let clampedLocation = min(max(editedSpan.location, 0), fullLength)
        let clampedLength = min(editedSpan.length, fullLength - clampedLocation)
        var region = nsString.lineRange(for: NSRange(location: clampedLocation, length: clampedLength))

        // Walk up to the context window above.
        for _ in 0..<editedWindowContextLines {
            guard region.location > 0 else { break }
            let previousLine = nsString.lineRange(for: NSRange(location: region.location - 1, length: 0))
            let grewBy = region.location - previousLine.location
            region = NSRange(location: previousLine.location, length: region.length + grewBy)
        }

        // Walk down to the context window below.
        for _ in 0..<editedWindowContextLines {
            let end = region.location + region.length
            guard end < fullLength else { break }
            let nextLine = nsString.lineRange(for: NSRange(location: end, length: 0))
            region = NSRange(location: region.location, length: (nextLine.location + nextLine.length) - region.location)
        }

        return region
    }

    // The character range of the currently visible lines, aligned to whole lines,
    // or nil when nothing is laid out yet. Used both by the visible-range keystroke
    // strategy and by the full path's viewport-first cold paint.
    static func viewportRegion(layoutTarget: TextView) -> NSRange? {
        var minLocation = Int.max
        var maxEnd = 0
        for linePosition in layoutTarget.layoutManager.visibleLines() {
            minLocation = min(minLocation, linePosition.range.location)
            maxEnd = max(maxEnd, linePosition.range.location + linePosition.range.length)
        }
        guard minLocation != Int.max, maxEnd > minLocation else { return nil }
        let viewport = NSRange(location: minLocation, length: maxEnd - minLocation)
        return layoutTarget.textStorage.mutableString.lineRange(for: viewport)
    }
}
