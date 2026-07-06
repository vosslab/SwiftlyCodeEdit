import Foundation
import RegexBuilder

public enum CodeLanguageID: String, CaseIterable, Hashable, Codable {
    case agda, bash, c, cpp, cSharp, css, dart, dockerfile, elixir, go, goMod, haskell, html, java, javascript
    case jsdoc, json, jsx, julia, kotlin, lua, markdown, markdownInline, objc, ocaml, ocamlInterface, perl, php
    case python, regex, ruby, rust, scala, sql, swift, toml, tsx, typescript, verilog, yaml, zig, plainText
}

public typealias TreeSitterLanguage = CodeLanguageID

public struct CodeLanguage: Hashable {
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

public enum DocumentationComments: Hashable {
    case single(String)
    case pair((String, String))
}
