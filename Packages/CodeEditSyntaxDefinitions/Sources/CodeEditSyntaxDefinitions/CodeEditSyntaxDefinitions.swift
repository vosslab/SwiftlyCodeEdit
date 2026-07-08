import Foundation
import CodeEditHighlighting

public enum CodeEditSyntaxDefinitions {
    public static func highlightSpans(text: String, language: String) -> [HighlightSpan] {
        SyntaxDefinitionRepository.shared.highlightSpans(text: text, language: language)
    }

    public static func debugSummary(language: String) -> String {
        SyntaxDefinitionRepository.shared.debugSummary(language: language)
    }

    public static func kateDefinitionXML(named name: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "xml", subdirectory: "Kate")
            ?? Bundle.module.url(forResource: name, withExtension: "xml")
        guard let url else {
            throw SyntaxDefinitionError.missingDefinition(name: name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

public enum SyntaxDefinitionError: Error, Equatable {
    case missingDefinition(name: String)
}

public struct SyntaxDefinition: Sendable {
    public let language: String
    public let aliases: [String]
    public let rootContext: String
    public let contexts: [String: SyntaxContext]
    public let rules: [SyntaxRule]

    public init(
        language: String,
        aliases: [String] = [],
        rootContext: String,
        contexts: [String: SyntaxContext] = [:],
        rules: [SyntaxRule]
    ) {
        self.language = language
        self.aliases = aliases
        self.rootContext = rootContext
        self.contexts = contexts
        self.rules = rules
    }
}

public struct SyntaxContext: Sendable {
    public let name: String
    public let attribute: String?
    public let lineEndContext: String?
    public let fallthroughContext: String?
    public let items: [SyntaxContextItem]

    public init(
        name: String,
        attribute: String? = nil,
        lineEndContext: String? = nil,
        fallthroughContext: String? = nil,
        items: [SyntaxContextItem]
    ) {
        self.name = name
        self.attribute = attribute
        self.lineEndContext = lineEndContext
        self.fallthroughContext = fallthroughContext
        self.items = items
    }
}

public enum SyntaxContextItem: Sendable {
    case rule(SyntaxRule)
    case include(String)
}

public struct SyntaxRule: Sendable {
    public let pattern: String
    public let token: HighlightToken
    public let styleName: String?
    public let context: String?
    public let lookAhead: Bool
    public let column: Int?
    public let firstNonSpace: Bool
    public let minimal: Bool

    public init(
        pattern: String,
        token: HighlightToken,
        styleName: String? = nil,
        context: String? = nil,
        lookAhead: Bool = false,
        column: Int? = nil,
        firstNonSpace: Bool = false,
        minimal: Bool = false
    ) {
        self.pattern = pattern
        self.token = token
        self.styleName = styleName
        self.context = context
        self.lookAhead = lookAhead
        self.column = column
        self.firstNonSpace = firstNonSpace
        self.minimal = minimal
    }
}

public final class SyntaxDefinitionRepository: @unchecked Sendable {
    public static let shared = SyntaxDefinitionRepository()

    private let lock = NSLock()
    private let fileURLs: [String: URL]
    private var definitions: [String: SyntaxDefinition] = [:]
    private var loadedFileNames: Set<String> = []

    private init() {
        self.fileURLs = SyntaxDefinitionLoader.loadBundledFileURLs()
    }

    public func highlightSpans(text: String, language: String) -> [HighlightSpan] {
        guard let definition = definition(for: language.lowercased()) else {
            return []
        }

        return KateContextRuleInterpreter.highlightSpans(text: text, definition: definition)
    }

    public func debugSummary(language: String) -> String {
        guard let definition = definition(for: language.lowercased()) else {
            return "definition=<missing>"
        }
        let contextSample = definition.contexts.keys.sorted().prefix(8).joined(separator: ",")
        let itemCount = definition.contexts.values.reduce(0) { $0 + $1.items.count }
        return "definition=\(definition.language) root=\(definition.rootContext) contexts=\(definition.contexts.count) items=\(itemCount) sampleContexts=[\(contextSample)]"
    }

    private func definition(for key: String) -> SyntaxDefinition? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = definitions[key] {
            return cached
        }

        if let definition = loadDefinition(forKey: key) {
            return definition
        }

        return loadFallbackDefinition(forKey: key)
    }

    private func loadDefinition(forKey key: String) -> SyntaxDefinition? {
        guard let url = fileURLs[key], !loadedFileNames.contains(url.lastPathComponent.lowercased()) else {
            return nil
        }
        guard let contents = try? String(contentsOf: url, encoding: .utf8),
              let definition = SyntaxDefinitionLoader.load(from: contents) else {
            return nil
        }

        cache(definition: definition, fileName: url.deletingPathExtension().lastPathComponent.lowercased())
        loadedFileNames.insert(url.lastPathComponent.lowercased())
        return definition
    }

    private func loadFallbackDefinition(forKey key: String) -> SyntaxDefinition? {
        for (fileName, url) in fileURLs where !loadedFileNames.contains(url.lastPathComponent.lowercased()) {
            guard let contents = try? String(contentsOf: url, encoding: .utf8),
                  let definition = SyntaxDefinitionLoader.load(from: contents) else {
                continue
            }
            cache(definition: definition, fileName: fileName)
            loadedFileNames.insert(url.lastPathComponent.lowercased())
            if let cached = definitions[key] {
                return cached
            }
        }
        return definitions[key]
    }

    private func cache(definition: SyntaxDefinition, fileName: String) {
        definitions[definition.language.lowercased()] = definition
        definitions[fileName] = definition
        for alias in definition.aliases {
            definitions[alias] = definition
        }
    }
}

enum SyntaxDefinitionLoader {
    static func loadBundledFileURLs() -> [String: URL] {
        if let manifestURL = Bundle.module.url(forResource: "index", withExtension: "json", subdirectory: "Vendor/Kate"),
           let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(SyntaxManifest.self, from: data) {
            var urls: [String: URL] = [:]
            for (language, fileName) in manifest.languages {
                if let url = Bundle.module.url(forResource: fileName, withExtension: nil, subdirectory: "Vendor/Kate") {
                    urls[language.lowercased()] = url
                }
            }
            if !urls.isEmpty {
                return urls
            }
        }

        let files = Bundle.module.urls(forResourcesWithExtension: "xml", subdirectory: nil) ?? []
        return Dictionary(uniqueKeysWithValues: files.map { ($0.deletingPathExtension().lastPathComponent.lowercased(), $0) })
    }

    static func load(from contents: String) -> SyntaxDefinition? {
        guard let language = firstMatch(in: contents, pattern: #"<language\b[^>]*\bname="([^"]+)""#) else {
            return nil
        }
        let aliases = extractAliases(from: contents)
        let rawContextTable = extractRawContexts(from: contents)
        let rootContext = extractRootContext(from: contents, contextTable: rawContextTable)

        let entities = extractEntities(from: contents)
        let lists = extractLists(from: contents, entities: entities)
        let contexts = buildContexts(from: rawContextTable, entities: entities, lists: lists)
        let rules = contexts[rootContext]?.items.compactMap { item -> SyntaxRule? in
            if case let .rule(rule) = item { return rule }
            return nil
        } ?? []
        return SyntaxDefinition(
            language: language,
            aliases: aliases,
            rootContext: rootContext,
            contexts: contexts,
            rules: rules
        )
    }

    private static func extractRootContext(from contents: String, contextTable: RawContextTable) -> String {
        if let match = firstMatch(in: contents, pattern: #"<highlighting\b[^>]*\bdefaultContext="([^"]+)""#) {
            return match
        }
        if contextTable.contexts["Start"] != nil {
            return "Start"
        }
        if contextTable.contexts["Normal"] != nil {
            return "Normal"
        }
        return contextTable.order.first ?? "Normal"
    }

    private static func extractAliases(from contents: String) -> [String] {
        guard let aliasText = firstMatch(in: contents, pattern: #"<language\b[^>]*\baliases="([^"]+)""#) else {
            return []
        }
        return aliasText
            .split(separator: Character(";"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private static func extractEntities(from contents: String) -> [String: String] {
        var entities: [String: String] = [:]
        let pattern = #"<!ENTITY\s+([A-Za-z0-9_:-]+)\s+"([^"]*)">"#
        for match in matches(in: contents, pattern: pattern) {
            guard match.count >= 3 else { continue }
            entities[match[1]] = match[2]
        }
        return entities
    }

    private static func extractLists(from contents: String, entities: [String: String]) -> [String: [String]] {
        var lists: [String: [String]] = [:]
        let listPattern = #"<list\b[^>]*\bname="([^"]+)"[^>]*>(.*?)</list>"#
        let itemPattern = #"<item>(.*?)</item>"#

        for listMatch in matches(in: contents, pattern: listPattern, options: [.dotMatchesLineSeparators]) {
            guard listMatch.count >= 3 else { continue }
            let listName = listMatch[1]
            let body = listMatch[2]
            let items = matches(in: body, pattern: itemPattern, options: [.dotMatchesLineSeparators])
                .compactMap { itemMatch -> String? in
                    guard itemMatch.count >= 2 else { return nil }
                    return expandEntities(itemMatch[1], entities: entities).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
            lists[listName] = items
        }
        return lists
    }

    private struct RawContextTable {
        let contexts: [String: RawContextBlock]
        let order: [String]
    }

    private struct RawContextBlock {
        let body: String
        let attributes: [String: String]
    }

    private static func extractRawContexts(from contents: String) -> RawContextTable {
        let contextPattern = #"<context\b([^>]*)>(.*?)</context>"#
        var contexts: [String: RawContextBlock] = [:]
        var order: [String] = []

        for match in matches(in: contents, pattern: contextPattern, options: [.dotMatchesLineSeparators]) {
            guard match.count >= 3 else { continue }
            let attributes = parseAttributes(match[1])
            guard let name = attributes["name"] else { continue }
            contexts[name] = RawContextBlock(body: match[2], attributes: attributes)
            order.append(name)
        }
        return RawContextTable(contexts: contexts, order: order)
    }

    private static func buildContexts(
        from contextTable: RawContextTable,
        entities: [String: String],
        lists: [String: [String]]
    ) -> [String: SyntaxContext] {
        var contexts: [String: SyntaxContext] = [:]
        for name in contextTable.order {
            guard let block = contextTable.contexts[name] else { continue }
            contexts[name] = SyntaxContext(
                name: name,
                attribute: block.attributes["attribute"],
                lineEndContext: block.attributes["lineEndContext"],
                fallthroughContext: block.attributes["fallthroughContext"],
                items: parseContextItems(from: block.body, entities: entities, lists: lists)
            )
        }
        return contexts
    }

    private static func parseContextItems(
        from contents: String,
        entities: [String: String],
        lists: [String: [String]]
    ) -> [SyntaxContextItem] {
        let tagPattern = #"<(IncludeRules|RegExpr|DetectChar|Detect2Chars|DetectSpaces|DetectIdentifier|StringDetect|WordDetect|AnyChar|Int|Float|RangeDetect|LineContinue|HlCStringChar|HlCChar|HlCOct|HlCHex|keyword)\b([^>]*)/?>"#
        return matches(in: contents, pattern: tagPattern, options: [.dotMatchesLineSeparators])
            .compactMap { match -> SyntaxContextItem? in
                guard match.count >= 3 else { return nil }
                let tag = match[1]
                let attributes = parseAttributes(match[2])
                if tag == "IncludeRules" {
                    guard let context = attributes["context"] else { return nil }
                    return .include(context)
                }
                return parseRule(tag: tag, attributes: attributes, entities: entities, lists: lists).map { .rule($0) }
            }
    }

    private static func parseRule(
        tag: String,
        attributes: [String: String],
        entities: [String: String],
        lists: [String: [String]]
    ) -> SyntaxRule? {
                let styleName = attributes["attribute"]
                let styleToken = styleName.map { highlightToken(for: $0) } ?? HighlightToken.plainText
                let insensitive = attributes["insensitive"]?.lowercased() == "true"
                let context = attributes["context"]
                let lookAhead = truthy(attributes["lookAhead"])
                let column = attributes["column"].flatMap(Int.init)
                let firstNonSpace = attributes["firstNonSpace"]?.lowercased() == "true"
                let minimal = attributes["minimal"]?.lowercased() == "true"

                switch tag {
                case "RegExpr":
                    guard let pattern = attributes["String"] else { return nil }
                    return SyntaxRule(
                        pattern: compiledPattern(expandPattern(pattern, entities: entities), insensitive: insensitive, minimal: minimal),
                        token: styleToken,
                        styleName: styleName,
                        context: context,
                        lookAhead: lookAhead,
                        column: column,
                        firstNonSpace: firstNonSpace,
                        minimal: minimal
                    )
                case "DetectChar":
                    guard let char = attributes["char"] else { return nil }
                    return SyntaxRule(pattern: compiledPattern(NSRegularExpression.escapedPattern(for: expandPattern(char, entities: entities)), insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "Detect2Chars":
                    guard let char = attributes["char"], let char1 = attributes["char1"] else { return nil }
                    let pattern = NSRegularExpression.escapedPattern(for: expandPattern(char, entities: entities)) + NSRegularExpression.escapedPattern(for: expandPattern(char1, entities: entities))
                    return SyntaxRule(pattern: compiledPattern(pattern, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "DetectSpaces":
                    return SyntaxRule(pattern: compiledPattern(#"[ \t]+"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "DetectIdentifier":
                    return SyntaxRule(pattern: compiledPattern(#"\b[A-Za-z_][A-Za-z0-9_]*\b"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "StringDetect":
                    guard let string = attributes["String"] else { return nil }
                    return SyntaxRule(pattern: compiledPattern(NSRegularExpression.escapedPattern(for: expandPattern(string, entities: entities)), insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "WordDetect":
                    guard let string = attributes["String"] else { return nil }
                    let escaped = NSRegularExpression.escapedPattern(for: expandPattern(string, entities: entities))
                    return SyntaxRule(pattern: compiledPattern(#"(?<!\w)"# + escaped + #"(?!\w)"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "AnyChar":
                    guard let string = attributes["String"] else { return nil }
                    let escaped = expandPattern(string, entities: entities)
                        .map { NSRegularExpression.escapedPattern(for: String($0)) }
                        .joined()
                    return SyntaxRule(pattern: compiledPattern("[" + escaped + "]", insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "Int":
                    return SyntaxRule(pattern: compiledPattern(#"\b\d+\b"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "Float":
                    return SyntaxRule(pattern: compiledPattern(#"\b\d+\.\d+(?:[eE][+-]?\d+)?\b"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "RangeDetect":
                    guard let char = attributes["char"], let char1 = attributes["char1"] else { return nil }
                    let open = NSRegularExpression.escapedPattern(for: expandPattern(char, entities: entities))
                    let close = NSRegularExpression.escapedPattern(for: expandPattern(char1, entities: entities))
                    return SyntaxRule(pattern: compiledPattern(open + #".*?"# + close, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "LineContinue":
                    return SyntaxRule(pattern: compiledPattern(#"\\"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "HlCStringChar":
                    return SyntaxRule(pattern: compiledPattern(#"\\(?:[0-7]{1,3}|x[0-9A-Fa-f]+|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|.)"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "HlCChar":
                    return SyntaxRule(pattern: compiledPattern(#"'(?:\\.|[^'\\])'"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "HlCOct":
                    return SyntaxRule(pattern: compiledPattern(#"\b0[0-7]+\b"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "HlCHex":
                    return SyntaxRule(pattern: compiledPattern(#"\b0[xX][0-9A-Fa-f]+\b"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "keyword":
                    guard let listName = attributes["String"], let items = lists[listName], !items.isEmpty else { return nil }
                    let escaped = items.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
                    return SyntaxRule(pattern: compiledPattern(#"(?<!\w)(?:"# + escaped + #")(?!\w)"#, insensitive: insensitive, minimal: minimal), token: styleToken, styleName: styleName, context: context, lookAhead: lookAhead, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                default:
                    return nil
                }
    }

    private static func compiledPattern(_ pattern: String, insensitive: Bool, minimal: Bool) -> String {
        let transformed = minimal ? makeMinimal(pattern) : pattern
        return insensitive ? "(?i)" + transformed : transformed
    }

    private static func makeMinimal(_ pattern: String) -> String {
        var result = ""
        var escaped = false
        var inClass = false
        var previousWasQuantifier = false
        for character in pattern {
            switch character {
            case "\\":
                result.append(character)
                escaped.toggle()
                previousWasQuantifier = false
            case "[" where !escaped:
                inClass = true
                result.append(character)
                previousWasQuantifier = false
            case "]" where !escaped:
                inClass = false
                result.append(character)
                previousWasQuantifier = false
            case "*", "+", "?":
                guard !escaped && !inClass else {
                    result.append(character)
                    escaped = false
                    previousWasQuantifier = false
                    continue
                }
                result.append(character)
                if !previousWasQuantifier {
                    result.append("?")
                }
                previousWasQuantifier = true
            default:
                result.append(character)
                escaped = false
                previousWasQuantifier = false
            }
        }
        return result
    }

    private static func deduplicated(_ rules: [SyntaxRule]) -> [SyntaxRule] {
        var seen = Set<String>()
        return rules.filter { rule in
            let key = "\(rule.pattern)\u{0}\(rule.token)"
            return seen.insert(key).inserted
        }
    }

    private static func truthy(_ value: String?) -> Bool {
        guard let normalized = value?.lowercased() else { return false }
        return normalized == "1" || normalized == "true"
    }

    private static func parseAttributes(_ source: String) -> [String: String] {
        var attributes: [String: String] = [:]
        let pattern = #"([A-Za-z0-9_:-]+)="([^"]*)""#
        for match in matches(in: source, pattern: pattern) {
            guard match.count >= 3 else { continue }
            attributes[match[1]] = match[2]
        }
        return attributes
    }

    private static func expandPattern(_ pattern: String, entities: [String: String]) -> String {
        decodeNumericEntities(expandEntities(pattern, entities: entities))
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func expandEntities(_ text: String, entities: [String: String]) -> String {
        var output = text
        for _ in 0..<8 {
            var replaced = false
            for (name, value) in entities {
                let entity = "&\(name);"
                if output.contains(entity) {
                    output = output.replacingOccurrences(of: entity, with: value)
                    replaced = true
                }
            }
            if !replaced { break }
        }
        return output
    }

    private static func decodeNumericEntities(_ text: String) -> String {
        let pattern = #"&#(?:x([0-9A-Fa-f]+)|([0-9]+));"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        var output = ""
        var lastIndex = text.startIndex
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        for match in regex.matches(in: text, range: fullRange) {
            guard let matchRange = Range(match.range, in: text) else { continue }
            output.append(contentsOf: text[lastIndex..<matchRange.lowerBound])

            let hexRange = Range(match.range(at: 1), in: text)
            let decimalRange = Range(match.range(at: 2), in: text)
            let scalarValue = hexRange
                .flatMap { UInt32(text[$0], radix: 16) }
                ?? decimalRange.flatMap { UInt32(text[$0], radix: 10) }
            if let scalarValue, let scalar = UnicodeScalar(scalarValue) {
                output.append(Character(scalar))
            } else {
                output.append(contentsOf: text[matchRange])
            }
            lastIndex = matchRange.upperBound
        }
        output.append(contentsOf: text[lastIndex...])
        return output
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let match = matches(in: text, pattern: pattern, options: [.dotMatchesLineSeparators]).first,
              match.count >= 2 else {
            return nil
        }
        return match[1]
    }

    private static func matches(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.matches(in: text, range: range).compactMap { result in
            (0..<result.numberOfRanges).compactMap { index in
                let range = result.range(at: index)
                guard let swiftRange = Range(range, in: text) else { return nil }
                return String(text[swiftRange])
            }
        }
    }

}

private func highlightToken(for attribute: String) -> HighlightToken {
    let value = attribute.lowercased()
    if value.contains("comment") { return .comment }
    if value.contains("string") || value.contains("char") { return .string }
    if value.contains("keyword") || value.contains("boolean") || value.contains("constant") { return .keyword }
    if value.contains("number") || value.contains("float") || value.contains("decimal") || value.contains("hex") { return .number }
    if value.contains("function") { return .function }
    if value.contains("type") || value.contains("data_type") { return .type }
    if value.contains("operator") || value.contains("separator") || value.contains("symbol") { return .operatorToken }
    if value.contains("markup") || value.contains("header") || value.contains("list") || value.contains("code") || value.contains("quote") { return .markup }
    return .plainText
}

private func isStyledAttribute(_ attribute: String) -> Bool {
    let value = attribute.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return !value.isEmpty && value != "normal text"
}

private struct SyntaxManifest: Decodable {
    let languages: [String: String]
}

enum KateContextRuleInterpreter {
    static func highlightSpans(text: String, definition: SyntaxDefinition) -> [HighlightSpan] {
        guard !text.isEmpty else { return [] }

        let rootContext = definition.contexts[definition.rootContext] == nil ? fallbackRootContext(definition) : definition.rootContext
        var evaluator = Evaluator(text: text, definition: definition, rootContext: rootContext)
        return evaluator.highlightSpans()
    }

    private static func fallbackRootContext(_ definition: SyntaxDefinition) -> String {
        if definition.contexts["Start"] != nil { return "Start" }
        if definition.contexts["Normal"] != nil { return "Normal" }
        return definition.contexts.keys.sorted().first ?? definition.rootContext
    }

    private struct Evaluator {
        let text: String
        let definition: SyntaxDefinition
        let rootContext: String
        var index: String.Index
        var contextStack: [String]
        var regexCache: [String: NSRegularExpression] = [:]
        var failedRegexPatterns: Set<String> = []
        var expandedItemCache: [String: [SyntaxContextItem]] = [:]
        var spans: [HighlightSpan] = []
        var stepCount = 0

        init(text: String, definition: SyntaxDefinition, rootContext: String) {
            self.text = text
            self.definition = definition
            self.rootContext = rootContext
            self.index = text.startIndex
            self.contextStack = [rootContext]
        }

        mutating func highlightSpans() -> [HighlightSpan] {
            while index < text.endIndex {
                stepCount += 1
                guard stepCount <= max(10_000, text.count * 200) else {
                    return spans
                }

                guard let context = currentContext else {
                    advance()
                    continue
                }

                if text[index] == "\n" {
                    applyContextTransition(context.lineEndContext)
                    advance()
                    continue
                }

                if let match = firstMatch(in: context, at: index) {
                    apply(match, in: context)
                    continue
                }

                if let fallthroughContext = context.fallthroughContext {
                    applyContextTransition(fallthroughContext)
                    continue
                }

                if let span = defaultSpan(in: context, at: index) {
                    spans.append(span)
                }
                advance()
            }
            return spans.sorted(by: {
                let left = NSRange($0.range, in: text)
                let right = NSRange($1.range, in: text)
                if left.location != right.location { return left.location < right.location }
                return left.length > right.length
            })
        }

        private var currentContext: SyntaxContext? {
            contextStack.last.flatMap { definition.contexts[$0] }
        }

        private mutating func apply(_ match: RuleMatch, in context: SyntaxContext) {
            if !match.rule.lookAhead, shouldEmit(rule: match.rule) {
                spans.append(HighlightSpan(range: match.range, token: match.rule.token, styleName: match.rule.styleName))
            } else if !match.rule.lookAhead, let defaultSpan = defaultSpan(for: match.range, in: context) {
                spans.append(defaultSpan)
            }
            let previousIndex = index
            let previousStack = contextStack
            applyContextTransition(match.rule.context)
            if !match.rule.lookAhead {
                index = match.range.upperBound
            } else if match.rule.context == nil || match.rule.context == "#stay" {
                advance()
            }
            if index == previousIndex, contextStack == previousStack {
                advance()
            }
        }

        private mutating func advance() {
            guard index < text.endIndex else { return }
            index = text.index(after: index)
        }

        private func defaultSpan(in context: SyntaxContext, at index: String.Index) -> HighlightSpan? {
            guard let styleName = context.attribute,
                  isStyledAttribute(styleName),
                  text[index] != "\n" else {
                return nil
            }
            let nextIndex = text.index(after: index)
            return HighlightSpan(range: index..<nextIndex, token: highlightToken(for: styleName), styleName: styleName)
        }

        private func defaultSpan(for range: Range<String.Index>, in context: SyntaxContext) -> HighlightSpan? {
            guard let styleName = context.attribute, isStyledAttribute(styleName) else {
                return nil
            }
            return HighlightSpan(range: range, token: highlightToken(for: styleName), styleName: styleName)
        }

        private func shouldEmit(rule: SyntaxRule) -> Bool {
            guard let styleName = rule.styleName, isStyledAttribute(styleName) else {
                return false
            }
            return true
        }

        private mutating func firstMatch(in context: SyntaxContext, at index: String.Index) -> RuleMatch? {
            for item in expandedItems(for: context.name) {
                guard case let .rule(rule) = item,
                      let match = match(rule: rule, at: index) else {
                    continue
                }
                return match
            }
            return nil
        }

        private mutating func expandedItems(for contextName: String, active: Set<String> = []) -> [SyntaxContextItem] {
            if active.isEmpty, let cached = expandedItemCache[contextName] {
                return cached
            }
            guard let context = definition.contexts[contextName], !active.contains(contextName) else {
                return []
            }

            var nextActive = active
            nextActive.insert(contextName)

            var items: [SyntaxContextItem] = []
            for item in context.items {
                switch item {
                case let .include(includeName):
                    items.append(contentsOf: expandedItems(for: normalizedIncludeName(includeName), active: nextActive))
                case .rule:
                    items.append(item)
                }
            }
            if active.isEmpty {
                expandedItemCache[contextName] = items
            }
            return items
        }

        private func normalizedIncludeName(_ includeName: String) -> String {
            if includeName.hasPrefix("##") {
                return String(includeName.dropFirst(2))
            }
            return includeName
        }

        private mutating func match(rule: SyntaxRule, at index: String.Index) -> RuleMatch? {
            guard let regex = compiledRegex(for: rule.pattern) else {
                return nil
            }
            let location = NSRange(index..<index, in: text).location
            let searchRange = NSRange(location: location, length: (text as NSString).length - location)
            guard let result = regex.firstMatch(in: text, options: [.anchored], range: searchRange),
                  result.range.length > 0,
                  let range = Range(result.range, in: text) else {
                return nil
            }
            if let column = rule.column, column != actualColumn(for: range.lowerBound) {
                return nil
            }
            if rule.firstNonSpace, !isFirstNonSpace(range.lowerBound) {
                return nil
            }
            return RuleMatch(rule: rule, range: range)
        }

        private mutating func compiledRegex(for pattern: String) -> NSRegularExpression? {
            if let cached = regexCache[pattern] {
                return cached
            }
            if failedRegexPatterns.contains(pattern) {
                return nil
            }
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                failedRegexPatterns.insert(pattern)
                return nil
            }
            regexCache[pattern] = regex
            return regex
        }

        private func actualColumn(for index: String.Index) -> Int {
            let lineStart = text[..<index].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
            return text.distance(from: lineStart, to: index)
        }

        private func isFirstNonSpace(_ index: String.Index) -> Bool {
            let lineStart = text[..<index].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
            return !text[lineStart..<index].contains(where: { !$0.isWhitespace })
        }

        private mutating func applyContextTransition(_ rawTransition: String?) {
            guard let rawTransition, !rawTransition.isEmpty, rawTransition != "#stay" else {
                return
            }

            var transition = rawTransition
            while transition.hasPrefix("#pop") {
                popContext()
                transition.removeFirst("#pop".count)
                if transition.hasPrefix("!") {
                    transition.removeFirst()
                    if !transition.isEmpty {
                        pushContext(transition)
                    }
                    return
                }
            }

            if transition.isEmpty {
                return
            }
            pushContext(transition)
        }

        private mutating func popContext() {
            guard contextStack.count > 1 else { return }
            contextStack.removeLast()
        }

        private mutating func pushContext(_ contextName: String) {
            let normalized = normalizedIncludeName(contextName)
            guard definition.contexts[normalized] != nil else { return }
            contextStack.append(normalized)
        }
    }

    private struct RuleMatch {
        let rule: SyntaxRule
        let range: Range<String.Index>
    }
}

enum RegexRuleInterpreter {
    static func highlightSpans(text: String, rules: [SyntaxRule]) -> [HighlightSpan] {
        let fullLength = (text as NSString).length
        guard fullLength > 0 else { return [] }

        var occupied = Array(repeating: false, count: fullLength)
        var highlightedSpans: [HighlightSpan] = []

        for rule in rules {
            for span in spans(for: text, rule: rule) {
                guard span.token != .plainText else { continue }
                let nsRange = NSRange(span.range, in: text)
                guard nsRange.location != NSNotFound, nsRange.length > 0 else { continue }
                guard !isOccupied(occupied, range: nsRange) else { continue }
                markOccupied(&occupied, range: nsRange)
                highlightedSpans.append(span)
            }
        }

        return highlightedSpans.sorted(by: {
            let left = NSRange($0.range, in: text)
            let right = NSRange($1.range, in: text)
            if left.location != right.location { return left.location < right.location }
            return left.length > right.length
        })
    }

    static func spans(for text: String, rule: SyntaxRule) -> [HighlightSpan] {
        guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.anchorsMatchLines]) else { return [] }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        return regex.matches(in: text, range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            if let column = rule.column {
                let lineStart = text[..<range.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
                let actualColumn = text.distance(from: lineStart, to: range.lowerBound)
                if actualColumn != column {
                    return nil
                }
            }
            if rule.firstNonSpace {
                let lineStart = text[..<range.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
                let prefix = text[lineStart..<range.lowerBound]
                if prefix.contains(where: { !$0.isWhitespace }) {
                    return nil
                }
            }
            return HighlightSpan(range: range, token: rule.token, styleName: rule.styleName)
        }
    }

    private static func isOccupied(_ occupied: [Bool], range: NSRange) -> Bool {
        guard range.location >= 0, range.length > 0 else { return true }
        let upperBound = min(occupied.count, range.upperBound)
        guard range.location < upperBound else { return true }
        return occupied[range.location..<upperBound].contains(true)
    }

    private static func markOccupied(_ occupied: inout [Bool], range: NSRange) {
        guard range.location >= 0, range.length > 0 else { return }
        let upperBound = min(occupied.count, range.upperBound)
        guard range.location < upperBound else { return }
        for index in range.location..<upperBound {
            occupied[index] = true
        }
    }
}
