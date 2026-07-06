import Foundation

public protocol SyntaxHighlighter: Sendable {
    func highlight(
        text: String,
        language: String,
        visibleRange: Range<String.Index>,
        editRange: Range<String.Index>?
    ) -> [HighlightSpan]
}
