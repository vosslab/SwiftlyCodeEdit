import Foundation
import RegexBuilder

public enum CodeLanguageID: String, CaseIterable, Hashable, Codable {
    case agda, bash, c, cpp, cSharp, css, dart, dockerfile, elixir, go, goMod, haskell, html, java, javascript
    case jsdoc, json, jsx, julia, kotlin, lua, markdown, markdownInline, objc, ocaml, ocamlInterface, perl, php
    case python, regex, ruby, rust, scala, sql, swift, toml, tsx, typescript, verilog, yaml, zig, plainText
}

public typealias TreeSitterLanguage = CodeLanguageID

public struct CodeLanguage: @unchecked Sendable {
    internal init(
        id: CodeLanguageID,
        tsName: String,
        extensions: Set<String>,
        lineCommentString: String,
        rangeCommentStrings: (String, String),
        documentationCommentStrings: Set<DocumentationComments> = [],
        parentURL: URL? = nil,
        highlights: Set<String>? = nil,
        additionalIdentifiers: Set<String> = []
    ) {
        self.id = id
        self.tsName = tsName
        self.extensions = extensions
        self.lineCommentString = lineCommentString
        self.rangeCommentStrings = rangeCommentStrings
        self.documentationCommentStrings = documentationCommentStrings
        self.parentQueryURL = parentURL
        self.additionalHighlights = highlights
        self.additionalIdentifiers = additionalIdentifiers
    }

    public let id: CodeLanguageID
    public let tsName: String
    public let extensions: Set<String>
    public let lineCommentString: String
    public let rangeCommentStrings: (String, String)
    public let documentationCommentStrings: Set<DocumentationComments>
    public let parentQueryURL: URL?
    public let additionalHighlights: Set<String>?
    public let additionalIdentifiers: Set<String>
    public var queryURL: URL? { nil }
    internal var resourceURL: URL? = Bundle.module.resourceURL

    public var language: URL? { nil }
}

extension CodeLanguage {
    public static let `default`: CodeLanguage = .swift
}

extension CodeLanguage: Hashable {
    public static func == (lhs: CodeLanguage, rhs: CodeLanguage) -> Bool {
        lhs.id == rhs.id
            && lhs.tsName == rhs.tsName
            && lhs.extensions == rhs.extensions
            && lhs.lineCommentString == rhs.lineCommentString
            && lhs.rangeCommentStrings.0 == rhs.rangeCommentStrings.0
            && lhs.rangeCommentStrings.1 == rhs.rangeCommentStrings.1
            && lhs.documentationCommentStrings == rhs.documentationCommentStrings
            && lhs.parentQueryURL == rhs.parentQueryURL
            && lhs.additionalHighlights == rhs.additionalHighlights
            && lhs.additionalIdentifiers == rhs.additionalIdentifiers
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(tsName)
        hasher.combine(extensions)
        hasher.combine(lineCommentString)
        hasher.combine(rangeCommentStrings.0)
        hasher.combine(rangeCommentStrings.1)
        hasher.combine(documentationCommentStrings)
        hasher.combine(parentQueryURL)
        hasher.combine(additionalHighlights)
        hasher.combine(additionalIdentifiers)
    }
}

public enum DocumentationComments {
    case single(String)
    case pair((String, String))

}

extension DocumentationComments: Hashable {
    public static func == (lhs: DocumentationComments, rhs: DocumentationComments) -> Bool {
        switch (lhs, rhs) {
        case let (.single(lhsValue), .single(rhsValue)):
            return lhsValue == rhsValue
        case let (.pair(lhsValue), .pair(rhsValue)):
            return lhsValue.0 == rhsValue.0 && lhsValue.1 == rhsValue.1
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .single(value):
            hasher.combine(0)
            hasher.combine(value)
        case let .pair(value):
            hasher.combine(1)
            hasher.combine(value.0)
            hasher.combine(value.1)
        }
    }
}
