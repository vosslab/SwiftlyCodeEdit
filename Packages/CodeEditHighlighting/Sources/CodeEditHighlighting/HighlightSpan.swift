import Foundation

public enum HighlightToken: Sendable, Hashable {
    case comment
    case string
    case keyword
    case number
    case function
    case type
    case operatorToken
    case markup
    case plainText
}

public struct HighlightSpan: Sendable, Hashable {
    public let range: Range<String.Index>
    public let token: HighlightToken
    public let styleName: String?
    // Additive UTF-16 offsets (NSRange-compatible), populated by the span-mapping
    // stage from the interpreter's offset-native token runs. Attribute application
    // uses this directly and skips the per-span Range<String.Index> -> NSRange
    // conversion walk. nil when a span is built without known offsets (identity
    // and equality ignore it, so it stays a pure performance cache).
    public let nsRange: NSRange?

    public init(
        range: Range<String.Index>,
        token: HighlightToken,
        styleName: String? = nil,
        nsRange: NSRange? = nil
    ) {
        self.range = range
        self.token = token
        self.styleName = styleName
        self.nsRange = nsRange
    }

    // Equality and hashing intentionally exclude nsRange: it is a derived offset
    // cache for `range`, not part of a span's identity. Two spans that agree on
    // range, token, and style are equal whether or not the cache is populated, so
    // span-set comparisons stay stable across the with/without-offset paths.
    public static func == (lhs: HighlightSpan, rhs: HighlightSpan) -> Bool {
        lhs.range == rhs.range && lhs.token == rhs.token && lhs.styleName == rhs.styleName
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(range)
        hasher.combine(token)
        hasher.combine(styleName)
    }
}
