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

    public init(range: Range<String.Index>, token: HighlightToken, styleName: String? = nil) {
        self.range = range
        self.token = token
        self.styleName = styleName
    }
}
