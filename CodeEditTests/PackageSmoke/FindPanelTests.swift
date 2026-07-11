//
//  FindPanelTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-10.
//
//  Covers the find-panel port: the pure FindEngine search paths and the
//  FindPanelModel behavior against a real headless TextView. These are the acceptance
//  criteria for the port -- literal and regex find, zero matches, invalid-regex inline
//  error, next/previous moving the visible selection, replace landing selection on the
//  replaced text, and Replace All being non-overlapping left-to-right and a single
//  undoable operation.
//

@testable import CodeEdit
import AppKit
import Foundation
import CodeEditTextView
import Testing

@MainActor
@Suite
struct FindPanelTests {
    // Builds an editor with an undo manager and a find model bound to it, presented in
    // find mode. Returns both so a test can drive the model and inspect the editor.
    private func makeModel(text: String) -> (FindPanelModel, TextView) {
        let textView = TextView(string: "")
        textView.setTextStorage(NSTextStorage(string: text))
        textView.setUndoManager(CEUndoManager())
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))

        let model = FindPanelModel()
        model.bind(target: TextViewFindTarget(textView: textView))
        return (model, textView)
    }

    // MARK: - FindEngine

    @Test
    func containsMatchesEscapeMetacharacters() {
        // A literal query with a regex metacharacter matches the literal text, not a
        // pattern: "a.b" finds "a.b" but not "axb".
        let result = FindEngine.findMatches(
            in: "a.b axb a.b",
            query: "a.b",
            method: .contains,
            matchCase: false
        )
        #expect(result == .success([NSRange(location: 0, length: 3), NSRange(location: 8, length: 3)]))
    }

    @Test
    func regularExpressionMatchesPattern() {
        let result = FindEngine.findMatches(
            in: "cat cot cut",
            query: "c.t",
            method: .regularExpression,
            matchCase: false
        )
        #expect(result == .success([
            NSRange(location: 0, length: 3),
            NSRange(location: 4, length: 3),
            NSRange(location: 8, length: 3)
        ]))
    }

    @Test
    func invalidRegularExpressionReturnsError() {
        let result = FindEngine.findMatches(
            in: "anything",
            query: "[",
            method: .regularExpression,
            matchCase: false
        )
        #expect(result == .failure(.invalidRegularExpression))
    }

    // MARK: - Find

    @Test
    func findPopulatesMatchesForLiteralQuery() {
        let (model, _) = makeModel(text: "foo bar foo baz foo")
        model.findText = "foo"
        model.performFind()
        #expect(model.matchCount == 3)
        #expect(model.errorMessage == nil)
    }

    @Test
    func zeroMatchesLeavesEmptyListAndNoError() {
        let (model, _) = makeModel(text: "foo bar baz")
        model.findText = "qux"
        model.performFind()
        #expect(model.matchCount == 0)
        #expect(model.errorMessage == nil)
    }

    @Test
    func invalidRegexSurfacesInlineErrorAndNoMatches() {
        let (model, _) = makeModel(text: "foo bar baz")
        model.findMethod = .regularExpression
        model.findText = "("
        model.performFind()
        #expect(model.matchCount == 0)
        #expect(model.errorMessage != nil)
    }

    // MARK: - Move

    @Test
    func nextAndPreviousMoveTheVisibleSelection() {
        let (model, textView) = makeModel(text: "foo bar foo baz foo")
        model.findText = "foo"
        model.performFind()
        // Matches sit at 0, 8, 16; the search starts on the one nearest the caret (0).
        #expect(model.currentMatchIndex == 0)

        model.moveToNextMatch()
        #expect(textView.selectedRange() == NSRange(location: 8, length: 3))

        model.moveToNextMatch()
        #expect(textView.selectedRange() == NSRange(location: 16, length: 3))

        model.moveToPreviousMatch()
        #expect(textView.selectedRange() == NSRange(location: 8, length: 3))
    }

    @Test
    func nextWrapsAroundWhenEnabled() {
        let (model, textView) = makeModel(text: "foo foo")
        model.findText = "foo"
        model.performFind()
        // From the first match, forward twice wraps back to the first.
        model.moveToNextMatch()
        #expect(textView.selectedRange() == NSRange(location: 4, length: 3))
        model.moveToNextMatch()
        #expect(textView.selectedRange() == NSRange(location: 0, length: 3))
    }

    // MARK: - Replace

    @Test
    func replaceCurrentMatchMutatesAndLandsSelectionOnReplacedText() {
        let (model, textView) = makeModel(text: "foo foo foo")
        model.findText = "foo"
        model.replaceText = "bar"
        model.performFind()
        #expect(model.currentMatchIndex == 0)

        model.replaceCurrentMatch()
        #expect(textView.string == "bar foo foo")
        // The selection lands on the inserted replacement text.
        #expect(textView.selectedRange() == NSRange(location: 0, length: 3))
        // The two remaining matches are re-scanned.
        #expect(model.matchCount == 2)
    }

    @Test
    func replaceAllReplacesEveryMatchLeftToRightNonOverlapping() {
        // "aa" in "aaaa" matches non-overlapping at 0 and 2; replacing each with "b"
        // yields "bb", proving the matches never overlap.
        let (model, textView) = makeModel(text: "aaaa")
        model.findText = "aa"
        model.replaceText = "b"
        model.performFind()
        #expect(model.matchCount == 2)

        model.replaceAllMatches()
        #expect(textView.string == "bb")
    }

    @Test
    func replaceAllLandsSelectionOnLastReplacementWithLengthChange() {
        // Replacement is longer than the match, so the last replacement's location
        // shifts by the growth of the earlier ones.
        let (model, textView) = makeModel(text: "foo foo foo")
        model.findText = "foo"
        model.replaceText = "bars"
        model.performFind()

        model.replaceAllMatches()
        #expect(textView.string == "bars bars bars")
        // Third "bars" begins at offset 10 after the first two each grew by one.
        #expect(textView.selectedRange() == NSRange(location: 10, length: 4))
        #expect(model.matchCount == 0)
    }

    @Test
    func replaceAllIsASingleUndoableOperation() {
        let (model, textView) = makeModel(text: "foo foo foo")
        model.findText = "foo"
        model.replaceText = "bar"
        model.performFind()

        model.replaceAllMatches()
        #expect(textView.string == "bar bar bar")

        // One undo restores the entire document: the sweep is one operation, not one
        // per match.
        textView.undoManager?.undo()
        #expect(textView.string == "foo foo foo")
    }

    // MARK: - External document changes

    @Test
    func replaceAfterExternalShrinkDoesNotCrashOrCorrupt() {
        let (model, textView) = makeModel(text: "foo foo foo")
        model.findText = "foo"
        model.performFind()
        // Land the active match on the last occurrence so its stored range is the one
        // that goes out of bounds when the document shrinks.
        model.moveToNextMatch()
        model.moveToNextMatch()
        #expect(model.matchCount == 3)

        // Mutate the document directly, outside the find flow, shrinking it so every
        // stored match range now points past the new end.
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.replaceCharacters(in: fullRange, with: "hi")
        #expect(textView.string == "hi")

        // Replacing the stale active match must not raise; the model drops the stale
        // matches and re-scans instead of acting on an out-of-bounds range.
        model.replaceCurrentMatch()
        #expect(textView.string == "hi")
        #expect(model.matchCount == 0)
    }

    @Test
    func moveAfterExternalShrinkDoesNotSelectOutOfBounds() {
        let (model, textView) = makeModel(text: "foo foo foo")
        model.findText = "foo"
        model.performFind()
        #expect(model.currentMatchIndex == 0)

        // Shrink the document directly so the later match ranges are now out of bounds.
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.replaceCharacters(in: fullRange, with: "hi")

        // Moving to the next (stale) match must not select past the end; the selection
        // stays within the shortened document.
        model.moveToNextMatch()
        let selected = textView.selectedRange()
        #expect(NSMaxRange(selected) <= (textView.string as NSString).length)
    }

    @Test
    func externalEditReScansMatchesWhilePresented() {
        let (model, textView) = makeModel(text: "foo foo foo")
        model.present(mode: .find)
        model.findText = "foo"
        model.performFind()
        #expect(model.matchCount == 3)

        // A user edit removes one occurrence. The editor reports the change and the
        // model re-scans, so its match list reflects the shortened document rather than
        // holding the three stale ranges.
        textView.replaceCharacters(in: NSRange(location: 0, length: 4), with: "")
        #expect(textView.string == "foo foo")
        model.handleExternalTextChange()
        #expect(model.matchCount == 2)
    }

    // MARK: - Presentation

    @Test
    func presentReplaceRevealsReplaceMode() {
        let (model, _) = makeModel(text: "foo")
        model.present(mode: .replace)
        #expect(model.isPresented)
        #expect(model.mode == .replace)
    }
}
