//
//  FindPanelTarget.swift
//  SwiftlyCodeEdit
//
//  The seam the find panel drives. The old CodeEditSourceEditor panel talked
//  to a `FindPanelTarget` that its view model down-cast to `TextViewController`
//  (FindPanelViewModel.swift:69) just to read cursor positions; that down-cast is the
//  dependency this port removes. Here the target is satisfied directly by the app's
//  `TextView`, so no controller is involved and the panel works against the plain
//  editor's editor surface.
//

import Foundation
import CodeEditTextView

/// What the find panel model needs from the editor: the text view to search and
/// mutate, the caret location to pick a starting match, and a way to move the visible
/// selection to a match. Implemented against a `TextView` with no controller in play.
@MainActor
protocol FindPanelTarget: AnyObject {
    /// The editor being searched. Weakly held by the concrete target so a closed
    /// window's editor is not kept alive by the panel.
    var textView: TextView? { get }

    /// The caret's document offset, used to choose the match nearest the cursor when a
    /// search first runs.
    var cursorLocation: Int { get }

    /// Moves the document's visible selection to `range`, optionally scrolling it into
    /// view. This is how next, previous, and replace land the selection on a match.
    func select(range: NSRange, scrollToVisible: Bool)
}

/// A `FindPanelTarget` backed by one editor `TextView`. Reads the caret from the
/// selection manager and moves the selection through it, so "next moves the visible
/// selection" is a real selection change the editor renders.
@MainActor
final class TextViewFindTarget: FindPanelTarget {
    weak var textView: TextView?

    init(textView: TextView) {
        self.textView = textView
    }

    var cursorLocation: Int {
        // Selection location, or 0 when there is no live editor or no selection yet.
        let location = textView?.selectedRange().location ?? 0
        return location == NSNotFound ? 0 : location
    }

    func select(range: NSRange, scrollToVisible: Bool) {
        guard let textView else { return }
        textView.selectionManager.setSelectedRange(range)
        if scrollToVisible {
            textView.scrollSelectionToVisible()
        }
    }
}
