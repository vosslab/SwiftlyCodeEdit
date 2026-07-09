import Foundation
import CodeEditHighlighting

// Public seams of the syntax-color pipeline. Each stage is pure text/data in,
// data out (no AppKit, no display side), and separately callable so any stage
// can be timed in isolation like an ammeter in a circuit. The display stage
// (spans -> NSTextStorage attributes) lives in the app, not this package.
//
//   parse:      Kate XML        -> SyntaxDefinition   (parseDefinition / definition)
//   interpret:  text + rules    -> [TokenRun]         (tokenRuns)
//   span-map:   [TokenRun]      -> [HighlightSpan]    (spans)
//
// highlightSpans composes all three for the common case.
public enum CodeEditSyntaxDefinitions {
    // Full pipeline: parse (cached) + interpret + span-map. Behavior-preserving
    // convenience over the three stage calls below.
    public static func highlightSpans(text: String, language: String) -> [HighlightSpan] {
        guard let definition = definition(forLanguage: language) else {
            return []
        }
        let runs = tokenRuns(text: text, definition: definition)
        return spans(from: runs, in: text)
    }

    // Parse stage (cached). Loads and parses the bundled Kate XML for `language`
    // once, then returns the cached rule structures on later calls.
    public static func definition(forLanguage language: String) -> SyntaxDefinition? {
        SyntaxDefinitionRepository.shared.definition(forLanguage: language.lowercased())
    }

    // Parse stage (uncached). Parses a Kate XML string straight into rule
    // structures with no caching, so the raw parse cost is measurable in
    // isolation. Normal callers use `definition(forLanguage:)` instead.
    public static func parseDefinition(kateXML: String) -> SyntaxDefinition? {
        SyntaxDefinitionLoader.load(from: kateXML)
    }

    // Interpretation stage. Walks the text against the definition's rules and
    // emits offset-native token runs (UTF-16 location/length), doing no
    // String.Index work.
    public static func tokenRuns(text: String, definition: SyntaxDefinition) -> [TokenRun] {
        KateContextRuleInterpreter.tokenRuns(text: text, definition: definition)
    }

    // Span-mapping stage. Converts offset-native token runs into HighlightSpans,
    // resolving each UTF-16 range to a String.Index range once and carrying the
    // offsets forward on the span so the display stage never reconverts.
    public static func spans(from tokenRuns: [TokenRun], in text: String) -> [HighlightSpan] {
        HighlightSpanMapper.spans(from: tokenRuns, in: text)
    }

    public static func debugSummary(language: String) -> String {
        SyntaxDefinitionRepository.shared.debugSummary(language: language)
    }

	public static func kateDefinitionXML(named name: String) throws -> String {
		let url = Bundle.module.url(forResource: name, withExtension: "xml")
		guard let url else {
			throw SyntaxDefinitionError.missingDefinition(name: name)
		}
        return try String(contentsOf: url, encoding: .utf8)
    }
}

// Interpretation-stage output: a token colored run addressed by UTF-16 offsets.
// UTF-16 location/length are NSRange-compatible and free during the interpreter's
// linear walk, so this is the natural boundary type between interpretation and
// span mapping. Ints (not NSRange) keep it trivially Sendable and Hashable.
public struct TokenRun: Sendable, Hashable {
    public let location: Int   // UTF-16 offset of the run start
    public let length: Int     // UTF-16 length of the run
    public let token: HighlightToken
    public let styleName: String?

    public init(location: Int, length: Int, token: HighlightToken, styleName: String? = nil) {
        self.location = location
        self.length = length
        self.token = token
        self.styleName = styleName
    }

    public var nsRange: NSRange {
        NSRange(location: location, length: length)
    }
}

// Span-mapping stage. Resolves each token run's UTF-16 range to a String.Index
// range once and keeps the offsets on the span (HighlightSpan.nsRange) so the
// display stage applies attributes without another conversion walk.
public enum HighlightSpanMapper {
    public static func spans(from tokenRuns: [TokenRun], in text: String) -> [HighlightSpan] {
        var spans: [HighlightSpan] = []
        spans.reserveCapacity(tokenRuns.count)
        for run in tokenRuns {
            let nsRange = run.nsRange
            guard let range = Range(nsRange, in: text) else {
                continue
            }
            spans.append(HighlightSpan(range: range, token: run.token, styleName: run.styleName, nsRange: nsRange))
        }
        return spans
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

// Conservative membership set for the first UTF-16 code unit a rule's regex can
// match, anchored at a scan position. The interpreter skips the expensive
// anchored regex whenever the current code unit is provably not in this set,
// which removes the bulk of the per-character, per-rule matching cost. The set
// MUST be a superset of every code unit the rule can actually begin with; when
// that cannot be guaranteed the rule carries no filter (`firstChar == nil`) and
// the regex always runs. An all-ASCII bitmap covers the common case; any allowed
// unit >= 128 flips `allowsNonASCII` so non-ASCII leads never get skipped.
public struct FirstCharFilter: Sendable, Hashable {
    private let low: UInt64   // membership for code units 0...63
    private let high: UInt64  // membership for code units 64...127
    public let allowsNonASCII: Bool

    public init(low: UInt64, high: UInt64, allowsNonASCII: Bool) {
        self.low = low
        self.high = high
        self.allowsNonASCII = allowsNonASCII
    }

    public func allows(codeUnit unit: UInt16) -> Bool {
        if unit >= 128 { return allowsNonASCII }
        if unit < 64 { return (low >> UInt64(unit)) & 1 == 1 }
        return (high >> UInt64(unit - 64)) & 1 == 1
    }
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
    // nil means "first character unknown, always run the regex".
    public let firstChar: FirstCharFilter?

    public init(
        pattern: String,
        token: HighlightToken,
        styleName: String? = nil,
        context: String? = nil,
        lookAhead: Bool = false,
        column: Int? = nil,
        firstNonSpace: Bool = false,
        minimal: Bool = false,
        firstChar: FirstCharFilter? = nil
    ) {
        self.pattern = pattern
        self.token = token
        self.styleName = styleName
        self.context = context
        self.lookAhead = lookAhead
        self.column = column
        self.firstNonSpace = firstNonSpace
        self.minimal = minimal
        self.firstChar = firstChar
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

    // Parse-stage seam: the cached lookup that turns a language name into parsed
    // rule structures. `key` is expected already lowercased by the caller.
    public func definition(forLanguage key: String) -> SyntaxDefinition? {
        definition(for: key)
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
        let tagPattern = #"<(IncludeRules|RegExpr|DetectChar|Detect2Chars|DetectSpaces|DetectIdentifier|StringDetect|WordDetect|AnyChar|Int|Float|RangeDetect|LineContinue|HlCStringChar|HlCChar|HlCOct|HlCHex|keyword)\b((?:[^">]|"[^"]*")*)/?>"#
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

        // Each tag yields the raw regex body plus a conservative leading-char
        // filter. Deriving the filter from the known tag semantics (rather than
        // re-parsing the finished regex) keeps it exact for the typed tags, which
        // are the overwhelming majority of rules; only free-form RegExpr falls
        // back to pattern analysis, and to nil when analysis is uncertain.
        let rawPattern: String
        let filter: FirstCharFilter?
        switch tag {
        case "RegExpr":
            guard let pattern = attributes["String"] else { return nil }
            let expanded = expandPattern(pattern, entities: entities)
            rawPattern = expanded
            filter = regexLeadingFilter(expanded, insensitive: insensitive)
        case "DetectChar":
            guard let char = attributes["char"] else { return nil }
            let expanded = expandPattern(char, entities: entities)
            rawPattern = NSRegularExpression.escapedPattern(for: expanded)
            filter = leadingUnitFilter(ofFirstCharIn: expanded, insensitive: insensitive)
        case "Detect2Chars":
            guard let char = attributes["char"], let char1 = attributes["char1"] else { return nil }
            let open = expandPattern(char, entities: entities)
            rawPattern = NSRegularExpression.escapedPattern(for: open) + NSRegularExpression.escapedPattern(for: expandPattern(char1, entities: entities))
            filter = leadingUnitFilter(ofFirstCharIn: open, insensitive: insensitive)
        case "DetectSpaces":
            rawPattern = #"[ \t]+"#
            filter = classFilter(units: [9, 32])
        case "DetectIdentifier":
            rawPattern = #"\b[A-Za-z_][A-Za-z0-9_]*\b"#
            filter = identifierStartFilter
        case "StringDetect":
            guard let string = attributes["String"] else { return nil }
            let expanded = expandPattern(string, entities: entities)
            rawPattern = NSRegularExpression.escapedPattern(for: expanded)
            filter = leadingUnitFilter(ofFirstCharIn: expanded, insensitive: insensitive)
        case "WordDetect":
            guard let string = attributes["String"] else { return nil }
            let expanded = expandPattern(string, entities: entities)
            rawPattern = #"(?<!\w)"# + NSRegularExpression.escapedPattern(for: expanded) + #"(?!\w)"#
            filter = leadingUnitFilter(ofFirstCharIn: expanded, insensitive: insensitive)
        case "AnyChar":
            guard let string = attributes["String"] else { return nil }
            let expanded = expandPattern(string, entities: entities)
            let escaped = expanded.map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "|")
            rawPattern = "(?:" + escaped + ")"
            filter = anyCharFilter(of: expanded, insensitive: insensitive)
        case "Int":
            rawPattern = #"\b\d+\b"#
            filter = digitFilter
        case "Float":
            rawPattern = #"\b\d+\.\d+(?:[eE][+-]?\d+)?\b"#
            filter = digitFilter
        case "RangeDetect":
            guard let char = attributes["char"], let char1 = attributes["char1"] else { return nil }
            let open = expandPattern(char, entities: entities)
            let close = NSRegularExpression.escapedPattern(for: expandPattern(char1, entities: entities))
            rawPattern = NSRegularExpression.escapedPattern(for: open) + #".*?"# + close
            filter = leadingUnitFilter(ofFirstCharIn: open, insensitive: insensitive)
        case "LineContinue":
            rawPattern = #"\\"#
            filter = classFilter(units: [92])
        case "HlCStringChar":
            rawPattern = #"\\(?:[0-7]{1,3}|x[0-9A-Fa-f]+|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|.)"#
            filter = classFilter(units: [92])
        case "HlCChar":
            rawPattern = #"'(?:\\.|[^'\\])'"#
            filter = classFilter(units: [39])
        case "HlCOct":
            rawPattern = #"\b0[0-7]+\b"#
            filter = classFilter(units: [48])
        case "HlCHex":
            rawPattern = #"\b0[xX][0-9A-Fa-f]+\b"#
            filter = classFilter(units: [48])
        case "keyword":
            guard let listName = attributes["String"], let items = lists[listName], !items.isEmpty else { return nil }
            let escaped = items.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            rawPattern = #"(?<!\w)(?:"# + escaped + #")(?!\w)"#
            filter = keywordFilter(items: items, insensitive: insensitive)
        default:
            return nil
        }

        return SyntaxRule(
            pattern: compiledPattern(rawPattern, insensitive: insensitive, minimal: minimal),
            token: styleToken,
            styleName: styleName,
            context: context,
            lookAhead: lookAhead,
            column: column,
            firstNonSpace: firstNonSpace,
            minimal: minimal,
            firstChar: filter
        )
    }

    // MARK: - Leading-character filters
    //
    // A rule's filter must be a superset of every UTF-16 code unit the rule can
    // begin matching at a scan position. Under-stating it would silently drop
    // matches, so every builder here errs toward inclusion (or nil = always run).

    private struct FirstCharAccumulator {
        private var low: UInt64 = 0
        private var high: UInt64 = 0
        private var allowsNonASCII = false
        private var isEmpty = true

        private mutating func insertRaw(_ unit: UInt16) {
            isEmpty = false
            if unit >= 128 {
                allowsNonASCII = true
            } else if unit < 64 {
                low |= (UInt64(1) << UInt64(unit))
            } else {
                high |= (UInt64(1) << UInt64(unit - 64))
            }
        }

        // Adds `unit` and, under case-insensitive matching, the opposite-case
        // ASCII letter so a folded lead is never skipped.
        mutating func insert(unit: UInt16, insensitive: Bool) {
            insertRaw(unit)
            guard insensitive else { return }
            if unit >= 65, unit <= 90 {
                insertRaw(unit + 32)
            } else if unit >= 97, unit <= 122 {
                insertRaw(unit - 32)
            }
        }

        mutating func insert(firstUnitOf text: String, insensitive: Bool) {
            guard let unit = text.utf16.first else { return }
            insert(unit: unit, insensitive: insensitive)
        }

        func makeFilter() -> FirstCharFilter? {
            guard !isEmpty else { return nil }
            return FirstCharFilter(low: low, high: high, allowsNonASCII: allowsNonASCII)
        }
    }

    private static let digitFilter: FirstCharFilter? = {
        var acc = FirstCharAccumulator()
        for unit in UInt16(48)...UInt16(57) { acc.insert(unit: unit, insensitive: false) }
        return acc.makeFilter()
    }()

    private static let identifierStartFilter: FirstCharFilter? = {
        var acc = FirstCharAccumulator()
        acc.insert(unit: 95, insensitive: false)               // underscore
        for unit in UInt16(65)...UInt16(90) { acc.insert(unit: unit, insensitive: false) }   // A-Z
        for unit in UInt16(97)...UInt16(122) { acc.insert(unit: unit, insensitive: false) }  // a-z
        return acc.makeFilter()
    }()

    private static func classFilter(units: [UInt16]) -> FirstCharFilter? {
        var acc = FirstCharAccumulator()
        for unit in units { acc.insert(unit: unit, insensitive: false) }
        return acc.makeFilter()
    }

    private static func leadingUnitFilter(ofFirstCharIn text: String, insensitive: Bool) -> FirstCharFilter? {
        var acc = FirstCharAccumulator()
        acc.insert(firstUnitOf: text, insensitive: insensitive)
        return acc.makeFilter()
    }

    private static func keywordFilter(items: [String], insensitive: Bool) -> FirstCharFilter? {
        var acc = FirstCharAccumulator()
        for item in items { acc.insert(firstUnitOf: item, insensitive: insensitive) }
        return acc.makeFilter()
    }

    private static func anyCharFilter(of text: String, insensitive: Bool) -> FirstCharFilter? {
        var acc = FirstCharAccumulator()
        for character in text { acc.insert(firstUnitOf: String(character), insensitive: insensitive) }
        return acc.makeFilter()
    }

    // Best-effort leading-character analysis for free-form RegExpr patterns.
    // Deliberately narrow: it handles one required leading atom and bails to nil
    // on anything it does not fully model (alternation, groups, optional leads).
    // Bailing only costs a always-run regex; understating would drop matches.
    private static func regexLeadingFilter(_ pattern: String, insensitive: Bool) -> FirstCharFilter? {
        let chars = Array(pattern)
        let count = chars.count
        guard count > 0, !hasTopLevelAlternation(chars) else { return nil }

        var index = 0
        // Skip leading zero-width assertions that consume no characters.
        while index < count {
            if chars[index] == "^" {
                index += 1
                continue
            }
            if chars[index] == "\\", index + 1 < count, chars[index + 1] == "b" || chars[index + 1] == "B" {
                index += 2
                continue
            }
            break
        }
        guard index < count else { return nil }

        var acc = FirstCharAccumulator()
        let atomEnd: Int
        switch chars[index] {
        case "\\":
            guard index + 1 < count else { return nil }
            let escaped = chars[index + 1]
            switch escaped {
            case "d":
                for unit in UInt16(48)...UInt16(57) { acc.insert(unit: unit, insensitive: false) }
            case "w":
                acc.insert(unit: 95, insensitive: false)
                for unit in UInt16(48)...UInt16(57) { acc.insert(unit: unit, insensitive: false) }
                for unit in UInt16(65)...UInt16(90) { acc.insert(unit: unit, insensitive: false) }
                for unit in UInt16(97)...UInt16(122) { acc.insert(unit: unit, insensitive: false) }
            case "s":
                for unit in [UInt16(9), 10, 11, 12, 13, 32] { acc.insert(unit: unit, insensitive: false) }
            case "D", "W", "S", "b", "B":
                return nil                                  // negated class or boundary: too broad
            default:
                // An escaped non-alphanumeric is that literal; an escaped letter
                // or digit is an unmodeled escape (for example \u, \x, \1).
                if escaped.isLetter || escaped.isNumber { return nil }
                acc.insert(firstUnitOf: String(escaped), insensitive: insensitive)
            }
            atomEnd = index + 2
        case "[":
            guard let end = analyzeCharacterClass(chars, openIndex: index, into: &acc, insensitive: insensitive) else {
                return nil
            }
            atomEnd = end
        case ".", "$", "*", "+", "?", "(", ")", "|", "{":
            return nil                                      // metacharacter we do not model
        default:
            acc.insert(firstUnitOf: String(chars[index]), insensitive: insensitive)
            atomEnd = index + 1
        }

        // The leading atom must be required; a zero-allowing quantifier would let
        // the following atom supply the first character, which we do not track.
        if atomEnd < count {
            let quantifier = chars[atomEnd]
            if quantifier == "?" || quantifier == "*" {
                return nil
            }
            if quantifier == "{", braceQuantifierAllowsZero(chars, braceIndex: atomEnd) {
                return nil
            }
        }
        return acc.makeFilter()
    }

    // True when an unescaped `|` sits at the top level (outside any group or
    // character class), signalling an alternation this analyzer will not split.
    private static func hasTopLevelAlternation(_ chars: [Character]) -> Bool {
        var depth = 0
        var inClass = false
        var index = 0
        while index < chars.count {
            let character = chars[index]
            if character == "\\" {
                index += 2
                continue
            }
            if inClass {
                if character == "]" { inClass = false }
            } else if character == "[" {
                inClass = true
            } else if character == "(" {
                depth += 1
            } else if character == ")" {
                depth = max(0, depth - 1)
            } else if character == "|", depth == 0 {
                return true
            }
            index += 1
        }
        return false
    }

    // Parses a non-negated `[...]` class starting at `openIndex`, adding every
    // member's leading unit to `acc`. Returns the index just past `]`, or nil on
    // negation or any member it cannot resolve to concrete units.
    private static func analyzeCharacterClass(
        _ chars: [Character],
        openIndex: Int,
        into acc: inout FirstCharAccumulator,
        insensitive: Bool
    ) -> Int? {
        let count = chars.count
        var index = openIndex + 1
        guard index < count, chars[index] != "^" else { return nil }

        while index < count, chars[index] != "]" {
            // POSIX class ([:name:]), equivalence class ([=c=]), or collating
            // element ([.name.]) nested inside the class. Their real member sets
            // (for example [[:cntrl:]] = control bytes) are not the literal chars
            // that follow, so modelling them as literals would silently exclude
            // matchable characters. Bail to nil (always-run) instead.
            if chars[index] == "[", index + 1 < count,
               chars[index + 1] == ":" || chars[index + 1] == "=" || chars[index + 1] == "." {
                return nil
            }
            guard let (lowUnit, lowIsSet, afterLow) = readClassMember(chars, at: index, into: &acc, insensitive: insensitive) else {
                return nil
            }
            // A range low-high only applies when both ends are single units.
            if !lowIsSet, afterLow < count, chars[afterLow] == "-", afterLow + 1 < count, chars[afterLow + 1] != "]" {
                guard let (highUnit, highIsSet, afterHigh) = readClassMember(chars, at: afterLow + 1, into: &acc, insensitive: insensitive),
                      !highIsSet, lowUnit <= highUnit else {
                    return nil
                }
                var unit = lowUnit
                while unit <= highUnit {
                    acc.insert(unit: unit, insensitive: insensitive)
                    unit += 1
                }
                index = afterHigh
            } else {
                acc.insert(unit: lowUnit, insensitive: insensitive)
                index = afterLow
            }
        }
        guard index < count, chars[index] == "]" else { return nil }
        return index + 1
    }

    // Reads one class member (literal, escaped char, or a \d/\w/\s set). For a
    // set it inserts directly into `acc` and reports lowIsSet = true so the
    // caller does not treat it as a range endpoint.
    private static func readClassMember(
        _ chars: [Character],
        at index: Int,
        into acc: inout FirstCharAccumulator,
        insensitive: Bool
    ) -> (unit: UInt16, isSet: Bool, next: Int)? {
        let count = chars.count
        guard index < count else { return nil }
        if chars[index] == "\\" {
            guard index + 1 < count else { return nil }
            let escaped = chars[index + 1]
            switch escaped {
            case "d":
                for unit in UInt16(48)...UInt16(57) { acc.insert(unit: unit, insensitive: false) }
                return (0, true, index + 2)
            case "w":
                acc.insert(unit: 95, insensitive: false)
                for unit in UInt16(48)...UInt16(57) { acc.insert(unit: unit, insensitive: false) }
                for unit in UInt16(65)...UInt16(90) { acc.insert(unit: unit, insensitive: false) }
                for unit in UInt16(97)...UInt16(122) { acc.insert(unit: unit, insensitive: false) }
                return (0, true, index + 2)
            case "s":
                for unit in [UInt16(9), 10, 11, 12, 13, 32] { acc.insert(unit: unit, insensitive: false) }
                return (0, true, index + 2)
            case "t": return (9, false, index + 2)
            case "n": return (10, false, index + 2)
            case "r": return (13, false, index + 2)
            case "f": return (12, false, index + 2)
            case "v": return (11, false, index + 2)
            case "D", "W", "S", "b", "B", "u", "x", "p", "P":
                return nil                                  // negated or unmodeled escape
            default:
                if escaped.isNumber { return nil }          // octal/backreference: unmodeled
                guard let unit = String(escaped).utf16.first else { return nil }
                return (unit, false, index + 2)
            }
        }
        guard let unit = String(chars[index]).utf16.first else { return nil }
        return (unit, false, index + 1)
    }

    // True when a `{m,n}` quantifier permits zero repetitions (m is 0 or absent).
    private static func braceQuantifierAllowsZero(_ chars: [Character], braceIndex: Int) -> Bool {
        let count = chars.count
        var index = braceIndex + 1
        var digits = ""
        while index < count, chars[index].isNumber {
            digits.append(chars[index])
            index += 1
        }
        // No closing brace means it is a literal `{`, not a quantifier.
        guard index < count, chars[index] == "," || chars[index] == "}" else { return false }
        return digits.isEmpty || Int(digits) == 0
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

enum KateContextRuleInterpreter {
    // Interpretation stage: text + rules -> offset-native token runs. This is the
    // interpreter's real output; it does no String.Index work. `applyFirstCharFilter`
    // is always true in production; tests set it false to prove the leading-char
    // prefilter is a pure optimization that never changes the emitted runs.
    static func tokenRuns(
        text: String,
        definition: SyntaxDefinition,
        applyFirstCharFilter: Bool = true
    ) -> [TokenRun] {
        guard !text.isEmpty else { return [] }

        let rootContext = definition.contexts[definition.rootContext] == nil ? fallbackRootContext(definition) : definition.rootContext
        var evaluator = Evaluator(
            text: text,
            definition: definition,
            rootContext: rootContext,
            applyFirstCharFilter: applyFirstCharFilter
        )
        return evaluator.evaluate()
    }

    // Convenience composition of interpretation + span mapping for callers (and
    // tests) that want spans directly from a definition and text.
    static func highlightSpans(
        text: String,
        definition: SyntaxDefinition,
        applyFirstCharFilter: Bool = true
    ) -> [HighlightSpan] {
        let runs = tokenRuns(text: text, definition: definition, applyFirstCharFilter: applyFirstCharFilter)
        return HighlightSpanMapper.spans(from: runs, in: text)
    }

    private static func fallbackRootContext(_ definition: SyntaxDefinition) -> String {
        if definition.contexts["Start"] != nil { return "Start" }
        if definition.contexts["Normal"] != nil { return "Normal" }
        return definition.contexts.keys.sorted().first ?? definition.rootContext
    }

    private struct Evaluator {
        let text: String
        // The text bridged to NSString once. NSRegularExpression works on UTF-16,
        // so every anchored match reuses this single bridge and the cached length
        // instead of re-bridging the whole string on every rule attempt (the old
        // hot-path cost). `location` is the UTF-16 offset of `index`, kept in
        // lockstep so a match never has to convert String.Index to an offset.
        let nsText: NSString
        let nsLength: Int
        // Runaway guard budget, computed once. Deriving it from `text.count`
        // inside the loop was O(n) per step (Swift counts graphemes by walking
        // the whole string), which made the whole pass O(n^2) and was the true
        // dominant cost of the cold pass.
        let stepBudget: Int
        let definition: SyntaxDefinition
        let rootContext: String
        let applyFirstCharFilter: Bool
        var index: String.Index
        var location: Int
        var contextStack: [String]
        var regexCache: [String: NSRegularExpression] = [:]
        var failedRegexPatterns: Set<String> = []
        var expandedItemCache: [String: [SyntaxContextItem]] = [:]
        var runs: [TokenRun] = []
        var stepCount = 0

        init(text: String, definition: SyntaxDefinition, rootContext: String, applyFirstCharFilter: Bool) {
            self.text = text
            self.applyFirstCharFilter = applyFirstCharFilter
            // Build a UTF-16-backed NSString from an explicit code-unit buffer.
            // A plain `text as NSString` bridge of a native (UTF-8) Swift string
            // has no contiguous UTF-16 store, so both `character(at:)` and every
            // anchored regex transcode UTF-16 on demand, which turns per-position
            // work into O(offset) and the whole pass into O(n^2). A real UTF-16
            // buffer makes both O(1).
            let units = Array(text.utf16)
            self.nsText = NSString(characters: units, length: units.count)
            self.nsLength = units.count
            // UTF-16 length is an upper bound on grapheme count, so this budget
            // is at least as generous as the old text.count * 200 guard.
            self.stepBudget = max(10_000, units.count * 200)
            self.definition = definition
            self.rootContext = rootContext
            self.index = text.startIndex
            self.location = 0
            self.contextStack = [rootContext]
        }

        mutating func evaluate() -> [TokenRun] {
            while index < text.endIndex {
                stepCount += 1
                guard stepCount <= stepBudget else {
                    return runs
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

                if let match = firstMatch(in: context, at: location) {
                    apply(match, in: context)
                    continue
                }

                if let fallthroughContext = context.fallthroughContext {
                    applyContextTransition(fallthroughContext)
                    continue
                }

                if let run = defaultRun(in: context) {
                    runs.append(run)
                }
                advance()
            }
            // Sort by start ascending, then by length descending. Runs carry UTF-16
            // offsets, so this compares plain Ints; the previous span sort had to
            // convert String.Index to NSRange twice per comparison.
            return runs.sorted(by: {
                if $0.location != $1.location {
                    return $0.location < $1.location
                }
                return $0.length > $1.length
            })
        }

        private var currentContext: SyntaxContext? {
            contextStack.last.flatMap { definition.contexts[$0] }
        }

        private mutating func apply(_ match: RuleMatch, in context: SyntaxContext) {
            if !match.rule.lookAhead, shouldEmit(rule: match.rule) {
                runs.append(TokenRun(
                    location: match.nsRange.location,
                    length: match.nsRange.length,
                    token: match.rule.token,
                    styleName: match.rule.styleName
                ))
            } else if !match.rule.lookAhead, let defaultRun = defaultRun(for: match.nsRange, in: context) {
                runs.append(defaultRun)
            }
            let previousIndex = index
            let previousStack = contextStack
            applyContextTransition(match.rule.context)
            if !match.rule.lookAhead {
                advanceCursor(toAtLeast: match.nsRange.location + match.nsRange.length)
            } else if match.rule.context == nil || match.rule.context == "#stay" {
                advance()
            }
            if index == previousIndex, contextStack == previousStack {
                advance()
            }
        }

        private mutating func advance() {
            guard index < text.endIndex else { return }
            // Keep the UTF-16 offset aligned with the grapheme cursor: a single
            // grapheme can span two code units (surrogate pairs, CRLF).
            location += text[index].utf16.count
            index = text.index(after: index)
        }

        // Advance the grapheme cursor to the first grapheme boundary at or past
        // `targetLocation` (a UTF-16 offset). Walking whole graphemes from the
        // current aligned position keeps `index` grapheme-aligned and `location`
        // its exact UTF-16 offset even when a match ends mid-grapheme -- for
        // example a regex that stops between a base character and its combining
        // mark. Deriving both cursors from this one walk removes the desync that a
        // direct `index = Range(nsRange, in: text).upperBound` jump could cause.
        private mutating func advanceCursor(toAtLeast targetLocation: Int) {
            while location < targetLocation, index < text.endIndex {
                location += text[index].utf16.count
                index = text.index(after: index)
            }
        }

        // Single-character default run at the current cursor. Uses the tracked
        // UTF-16 offset directly; the character's UTF-16 length gives the run width.
        private func defaultRun(in context: SyntaxContext) -> TokenRun? {
            guard let styleName = context.attribute,
                  isStyledAttribute(styleName),
                  text[index] != "\n" else {
                return nil
            }
            let length = text[index].utf16.count
            return TokenRun(location: location, length: length, token: highlightToken(for: styleName), styleName: styleName)
        }

        private func defaultRun(for nsRange: NSRange, in context: SyntaxContext) -> TokenRun? {
            guard let styleName = context.attribute, isStyledAttribute(styleName) else {
                return nil
            }
            return TokenRun(location: nsRange.location, length: nsRange.length, token: highlightToken(for: styleName), styleName: styleName)
        }

        private func shouldEmit(rule: SyntaxRule) -> Bool {
            guard let styleName = rule.styleName, isStyledAttribute(styleName) else {
                return false
            }
            return true
        }

        private mutating func firstMatch(in context: SyntaxContext, at location: Int) -> RuleMatch? {
            // One code-unit read per position drives the leading-char prefilter,
            // which skips the anchored regex for every rule that provably cannot
            // begin with this unit. That removes the bulk of the per-position,
            // per-rule matching that dominated the cold pass.
            let currentUnit = nsText.character(at: location)
            for item in expandedItems(for: context.name) {
                guard case let .rule(rule) = item else { continue }
                if applyFirstCharFilter, let filter = rule.firstChar, !filter.allows(codeUnit: currentUnit) {
                    continue
                }
                if let match = match(rule: rule, at: location) {
                    return match
                }
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

        private mutating func match(rule: SyntaxRule, at location: Int) -> RuleMatch? {
            guard let regex = compiledRegex(for: rule.pattern) else {
                return nil
            }
            let searchRange = NSRange(location: location, length: nsLength - location)
            // `nsText as String` re-wraps the already-bridged NSString in O(1),
            // so firstMatch never deep-copies the text on the hot path.
            guard let result = regex.firstMatch(in: nsText as String, options: [.anchored], range: searchRange),
                  result.range.length > 0 else {
                return nil
            }
            // The match is anchored at the current cursor, so `index` is its start.
            // The column and first-non-space checks need only that start position,
            // and working from `index` avoids converting the match's NSRange back to
            // a String.Index that could land mid-grapheme.
            if let column = rule.column, column != actualColumn(for: index) {
                return nil
            }
            if rule.firstNonSpace, !isFirstNonSpace(index) {
                return nil
            }
            return RuleMatch(rule: rule, nsRange: result.range)
        }

        // Two-level cache: a lock-free per-Evaluator dictionary on the hot path,
        // backed by a process-wide compiled-regex cache so repeated passes and
        // other documents reuse compilations instead of rebuilding them.
        private mutating func compiledRegex(for pattern: String) -> NSRegularExpression? {
            if let cached = regexCache[pattern] {
                return cached
            }
            if failedRegexPatterns.contains(pattern) {
                return nil
            }
            guard let regex = CompiledRegexCache.shared.regex(for: pattern) else {
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
        // UTF-16 range of the match, emitted directly into the token run. The
        // cursor advances to the grapheme boundary at or past nsRange's end, so a
        // match ending mid-grapheme never desyncs the grapheme cursor from its
        // UTF-16 offset.
        let nsRange: NSRange
    }
}

// Process-wide compiled-regex cache. NSRegularExpression instances are immutable
// and thread-safe once built, and every interpreter pass compiles with the same
// options, so a single pattern-keyed store lets repeated passes (drift recompute,
// per-keystroke reinterpret) and every open document share compilations instead
// of rebuilding them per Evaluator.
final class CompiledRegexCache: @unchecked Sendable {
    static let shared = CompiledRegexCache()

    private let lock = NSLock()
    private var cache: [String: NSRegularExpression] = [:]
    private var failedPatterns: Set<String> = []

    func regex(for pattern: String) -> NSRegularExpression? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[pattern] {
            return cached
        }
        if failedPatterns.contains(pattern) {
            return nil
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            failedPatterns.insert(pattern)
            return nil
        }
        cache[pattern] = regex
        return regex
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
