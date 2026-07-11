//
//  FindPanelModel.swift
//  SwiftlyCodeEdit
//
//  State and behavior for the find/replace bar. This is the port of the old
//  CodeEditSourceEditor `FindPanelViewModel`, re-expressed with the `Observable` macro
//  per the plan's Resolved decisions (not the old `ObservableObject`) and driven
//  against a `FindPanelTarget` over the app's `TextView` rather than a
//  `TextViewController`. The pure matching lives in `FindEngine`; this type owns panel
//  state, selection movement, and single-operation undo for replacement.
//

import Foundation
import Observation
import CodeEditTextView

@Observable
@MainActor
final class FindPanelModel {
    /// Whether the bar shows just find, or find plus replace.
    enum Mode {
        case find
        case replace
    }

    // The emphasis group id under which match highlights are registered on the text
    // view, kept separate from bracket-pair emphases so each is managed independently.
    private static let emphasisGroup = "codeedit.find"

    // The editor this panel acts on. Set when the panel is presented for a window; the
    // concrete target holds the text view weakly. Not observed: it is a wiring
    // reference, not display state.
    @ObservationIgnored private var target: (any FindPanelTarget)?

    // True only while the model is itself mutating the text (Replace / Replace All).
    // The editor reports every text change back to `handleExternalTextChange()`,
    // including the ones this model just made; this flag lets that handler tell the
    // model's own edits apart from a change made outside the find flow (user typing,
    // paste, undo, a Clean Text command). Not observed: it is internal wiring state.
    @ObservationIgnored private var isPerformingInternalEdit = false

    /// Whether the bar is on screen. The editor view shows the bar while this is true.
    var isPresented = false

    /// Find-only or find-and-replace layout.
    var mode: Mode = .find

    /// The search query. The view re-runs the search when this changes.
    var findText = ""

    /// The replacement string used by Replace and Replace All.
    var replaceText = ""

    /// How the query is interpreted (literal variants or regex).
    var findMethod: FindMethod = .contains

    /// Case-sensitive search when true; case-insensitive by default.
    var matchCase = false

    /// Whether next/previous wrap around the ends of the match list.
    var wrapAround = true

    /// Ranges of the current matches, in document order. Read by the view for the
    /// match count and by move/replace to act on the selected match.
    private(set) var matches: [NSRange] = []

    /// Index into `matches` of the active match, or nil when there are none.
    private(set) var currentMatchIndex: Int?

    /// Inline error text shown in the bar, set only when a regex query fails to
    /// compile. Cleared on every successful search and on dismiss.
    private(set) var errorMessage: String?

    /// Number of matches for the current query.
    var matchCount: Int {
        matches.count
    }

    // MARK: - Presentation

    /// Points the panel at an editor. Called once per window from the editor view as
    /// its text view becomes ready, so the router can later present this panel without
    /// re-supplying the target.
    func bind(target: any FindPanelTarget) {
        self.target = target
    }

    /// Shows the bar in the given mode and runs an initial search for any existing
    /// query. Invoked by the router for Cmd-F (find) and Cmd-Opt-F (replace).
    func present(mode: Mode) {
        self.mode = mode
        isPresented = true
        performFind()
    }

    /// Hides the bar and clears the match highlights and any inline error.
    func dismiss() {
        isPresented = false
        errorMessage = nil
        clearEmphases()
    }

    // MARK: - Find

    /// Runs the search for the current query and updates matches, the active index,
    /// and the inline error. Does not move the document selection; it only records
    /// where the matches are and highlights them.
    func performFind() {
        guard let text = target?.textView?.string else {
            matches = []
            currentMatchIndex = nil
            return
        }

        switch FindEngine.findMatches(in: text, query: findText, method: findMethod, matchCase: matchCase) {
        case .success(let ranges):
            errorMessage = nil
            matches = ranges
            let cursor = target?.cursorLocation ?? 0
            currentMatchIndex = FindEngine.nearestMatchIndex(to: cursor, in: ranges)
            refreshEmphases()
        case .failure:
            // A malformed regex shows an inline message and produces no matches,
            // rather than throwing or silently searching for nothing.
            errorMessage = "Invalid regular expression"
            matches = []
            currentMatchIndex = nil
            clearEmphases()
        }
    }

    /// Reacts to the bound editor's text changing. The editor calls this for every
    /// content change; the model's own Replace edits set `isPerformingInternalEdit` and
    /// are ignored here. Any other change while the bar is up is an external edit that
    /// can leave the stored match ranges pointing past the document's new length, so
    /// the search is re-run to keep `matches`, the active index, and the highlights in
    /// sync with the edited text. Re-scanning (rather than clearing) keeps the panel
    /// live and correct: the match count and highlights stay accurate as the user
    /// edits, which is the expected find-bar behavior; clearing would make the bar
    /// silently go blank mid-edit. The per-keystroke cost of this synchronous re-scan
    /// on large documents is tracked as a separate debounce task.
    func handleExternalTextChange() {
        guard !isPerformingInternalEdit else { return }
        guard isPresented else { return }
        performFind()
    }

    // MARK: - Move

    /// Advances the active match forward and moves the visible selection to it.
    func moveToNextMatch() {
        moveMatch(forwards: true)
    }

    /// Steps the active match backward and moves the visible selection to it.
    func moveToPreviousMatch() {
        moveMatch(forwards: false)
    }

    private func moveMatch(forwards: Bool) {
        guard !matches.isEmpty else { return }

        guard let index = currentMatchIndex else {
            // No active match yet: land on the first one.
            currentMatchIndex = 0
            selectCurrentMatch()
            return
        }

        let atLimit = forwards ? index == matches.count - 1 : index == 0
        // Without wrap-around, a move past either end stays put.
        guard !atLimit || wrapAround else { return }

        currentMatchIndex = if forwards {
            (index + 1) % matches.count
        } else {
            (index - 1 + matches.count) % matches.count
        }
        selectCurrentMatch()
    }

    // MARK: - Replace

    /// Replaces the active match with `replaceText` as one undoable edit, lands the
    /// selection on the inserted text, then re-scans so the remaining matches stay
    /// accurate.
    func replaceCurrentMatch() {
        guard let textView = target?.textView,
              let index = currentMatchIndex,
              matches.indices.contains(index) else {
            return
        }

        let range = matches[index]
        // A stored range can point past the document's end if the text shrank after
        // the search ran (an external edit the panel has not yet re-scanned). Replacing
        // an out-of-bounds range raises NSInvalidArgumentException, so drop the stale
        // matches and re-scan instead of acting on a bad range.
        guard rangeIsWithinDocument(range, of: textView) else {
            performFind()
            return
        }

        withInternalEdit {
            textView.replaceCharacters(in: range, with: replaceText)
        }

        // Selection lands on the just-inserted text.
        let replacedRange = NSRange(location: range.location, length: (replaceText as NSString).length)
        target?.select(range: replacedRange, scrollToVisible: true)

        // The document changed, so recompute matches; the caret now sits on the
        // replacement, so the next active match is the following one.
        performFind()
    }

    /// Replaces every match with `replaceText` as a single undoable operation, then
    /// lands the selection at the last replacement. Editing runs from the last match
    /// to the first so each replacement's offset stays valid without bookkeeping.
    func replaceAllMatches() {
        guard let textView = target?.textView, !matches.isEmpty else {
            return
        }

        // If any stored range points past the document's current end (an external edit
        // shrank the text since the search ran), the whole sweep is unsafe. Drop the
        // stale matches and re-scan rather than replacing against out-of-bounds ranges.
        guard matches.allSatisfy({ rangeIsWithinDocument($0, of: textView) }) else {
            performFind()
            return
        }

        let sorted = matches.sorted { $0.location < $1.location }

        // One undo group plus one text-storage editing batch make the whole sweep a
        // single undoable operation. Replacing from the last match to the first keeps
        // every not-yet-processed match's offset valid, so no bookkeeping is needed
        // during the loop.
        withInternalEdit {
            textView.undoManager?.beginUndoGrouping()
            textView.textStorage.beginEditing()
            for range in sorted.reversed() {
                textView.replaceCharacters(in: range, with: replaceText)
            }
            textView.textStorage.endEditing()
            textView.undoManager?.endUndoGrouping()
        }

        // Land the selection on the final replacement. Its start shifts by the total
        // length change of every earlier replacement (each earlier match contributes
        // replacement length minus its own length), since those sit before it.
        if let lastRange = sorted.last {
            let replaceLength = (replaceText as NSString).length
            let precedingShift = sorted.dropLast().reduce(0) { shift, range in
                shift + (replaceLength - range.length)
            }
            let replacedRange = NSRange(location: lastRange.location + precedingShift, length: replaceLength)
            target?.select(range: replacedRange, scrollToVisible: true)
        }

        matches = []
        currentMatchIndex = nil
        clearEmphases()
    }

    // MARK: - Selection and highlighting

    /// Moves the visible selection to the active match and refreshes the highlights.
    private func selectCurrentMatch() {
        guard let index = currentMatchIndex, matches.indices.contains(index) else { return }
        let range = matches[index]
        // The active range can be stale after an external edit shrank the document.
        // Selecting past the end lands the caret out of bounds, so drop the stale
        // matches and re-scan instead of moving the selection to a bad range.
        guard let textView = target?.textView, rangeIsWithinDocument(range, of: textView) else {
            performFind()
            return
        }
        target?.select(range: range, scrollToVisible: true)
        refreshEmphases()
    }

    /// Whether `range` fits entirely within the text view's current storage, so acting
    /// on it (selecting or replacing) is safe. A stale range left from a search run
    /// before an external edit can point past the end; this is the belt-and-braces
    /// bounds check that stops such a range from reaching `replaceCharacters` or the
    /// selection manager.
    private func rangeIsWithinDocument(_ range: NSRange, of textView: TextView) -> Bool {
        range.location >= 0 && NSMaxRange(range) <= textView.textStorage.length
    }

    /// Runs `body` with `isPerformingInternalEdit` set, so the text-change notifications
    /// the edit triggers are recognized as the model's own edits and do not re-scan.
    private func withInternalEdit(_ body: () -> Void) {
        isPerformingInternalEdit = true
        defer { isPerformingInternalEdit = false }
        body()
    }

    /// Draws a highlight over every match. Highlights are decorative only; selection
    /// is moved explicitly by the move and replace paths, so behavior does not depend
    /// on the highlight layer being rendered.
    private func refreshEmphases() {
        guard let emphasisManager = target?.textView?.emphasisManager else { return }
        emphasisManager.removeEmphases(for: Self.emphasisGroup)
        guard !matches.isEmpty else { return }
        let emphases = matches.enumerated().map { index, range in
            Emphasis(
                range: range,
                style: .standard,
                flash: false,
                inactive: index != currentMatchIndex,
                selectInDocument: false
            )
        }
        emphasisManager.addEmphases(emphases, for: Self.emphasisGroup)
    }

    private func clearEmphases() {
        target?.textView?.emphasisManager?.removeEmphases(for: Self.emphasisGroup)
    }
}
