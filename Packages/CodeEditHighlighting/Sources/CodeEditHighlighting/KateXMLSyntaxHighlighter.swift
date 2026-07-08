import Foundation

public final class KateXMLSyntaxHighlighter: SyntaxHighlighter, @unchecked Sendable {
    private let definition: KateSyntaxDefinition

    public init(definitionXML: String) throws {
        self.definition = try KateSyntaxDefinitionParser.parse(xml: definitionXML)
    }

    public func highlight(
        text: String,
        language: String,
        visibleRange: Range<String.Index>,
        editRange: Range<String.Index>?
    ) -> [HighlightSpan] {
        guard definition.matches(language: language) else { return [] }
        return KateContextInterpreter(definition: definition).highlight(text: text)
    }
}

private struct KateSyntaxDefinition {
    let name: String
    let contexts: [String: KateContext]
    let lists: [String: Set<String>]
    let itemData: [String: HighlightToken]

    func matches(language: String) -> Bool {
        name.caseInsensitiveCompare(language) == .orderedSame
    }
}

private struct KateContext {
    let name: String
    let attribute: String
    let lineEndContext: String
    let rules: [KateRule]
}

private struct KateRule {
    enum Kind {
        case detectChar(Character)
        case detect2Chars(Character, Character)
        case keyword(String)
        case regex(NSRegularExpression)
        case hlCStringChar
    }

    let kind: Kind
    let attribute: String
    let context: String?
}

private final class KateSyntaxDefinitionParser: NSObject, XMLParserDelegate {
    private var name = ""
    private var lists: [String: Set<String>] = [:]
    private var itemData: [String: HighlightToken] = [:]
    private var contexts: [String: KateContext] = [:]
    private var currentListName: String?
    private var currentListItems: [String] = []
    private var currentItemText = ""
    private var currentContextName: String?
    private var currentContextAttribute = "Normal Text"
    private var currentContextLineEnd = "#stay"
    private var currentRules: [KateRule] = []

    static func parse(xml: String) throws -> KateSyntaxDefinition {
        let parserDelegate = KateSyntaxDefinitionParser()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = parserDelegate
        guard parser.parse() else {
            throw parser.parserError ?? KateXMLSyntaxError.invalidXML
        }
        return KateSyntaxDefinition(
            name: parserDelegate.name,
            contexts: parserDelegate.contexts,
            lists: parserDelegate.lists,
            itemData: parserDelegate.itemData
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "language":
            name = attributeDict["name"] ?? ""
        case "list":
            currentListName = attributeDict["name"]
            currentListItems = []
        case "item":
            currentItemText = ""
        case "context":
            currentContextName = attributeDict["name"]
            currentContextAttribute = attributeDict["attribute"] ?? "Normal Text"
            currentContextLineEnd = attributeDict["lineEndContext"] ?? "#stay"
            currentRules = []
        case "DetectChar":
            appendDetectChar(attributeDict)
        case "Detect2Chars":
            appendDetect2Chars(attributeDict)
        case "keyword":
            appendKeyword(attributeDict)
        case "RegExpr":
            appendRegex(attributeDict)
        case "HlCStringChar":
            currentRules.append(KateRule(
                kind: .hlCStringChar,
                attribute: attributeDict["attribute"] ?? currentContextAttribute,
                context: attributeDict["context"]
            ))
        case "itemData":
            if let itemName = attributeDict["name"], let style = attributeDict["defStyleNum"] {
                itemData[itemName] = HighlightToken(kateStyle: style)
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentListName != nil {
            currentItemText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "item":
            let trimmed = currentItemText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                currentListItems.append(trimmed)
            }
            currentItemText = ""
        case "list":
            if let currentListName {
                lists[currentListName] = Set(currentListItems)
            }
            currentListName = nil
            currentListItems = []
        case "context":
            if let currentContextName {
                contexts[currentContextName] = KateContext(
                    name: currentContextName,
                    attribute: currentContextAttribute,
                    lineEndContext: currentContextLineEnd,
                    rules: currentRules
                )
            }
            currentContextName = nil
            currentRules = []
        default:
            break
        }
    }

    private func appendDetectChar(_ attributes: [String: String]) {
        guard let char = attributes["char"]?.first else { return }
        currentRules.append(KateRule(
            kind: .detectChar(char),
            attribute: attributes["attribute"] ?? currentContextAttribute,
            context: attributes["context"]
        ))
    }

    private func appendDetect2Chars(_ attributes: [String: String]) {
        guard let char = attributes["char"]?.first, let char1 = attributes["char1"]?.first else { return }
        currentRules.append(KateRule(
            kind: .detect2Chars(char, char1),
            attribute: attributes["attribute"] ?? currentContextAttribute,
            context: attributes["context"]
        ))
    }

    private func appendKeyword(_ attributes: [String: String]) {
        guard let listName = attributes["String"] else { return }
        currentRules.append(KateRule(
            kind: .keyword(listName),
            attribute: attributes["attribute"] ?? currentContextAttribute,
            context: attributes["context"]
        ))
    }

    private func appendRegex(_ attributes: [String: String]) {
        guard let pattern = attributes["String"],
              let regex = try? NSRegularExpression(pattern: pattern) else {
            return
        }
        currentRules.append(KateRule(
            kind: .regex(regex),
            attribute: attributes["attribute"] ?? currentContextAttribute,
            context: attributes["context"]
        ))
    }
}

private struct KateContextInterpreter {
    let definition: KateSyntaxDefinition

    func highlight(text: String) -> [HighlightSpan] {
        guard !text.isEmpty else { return [] }
        var spans: [HighlightSpan] = []
        var contextStack = ["Normal"]
        var index = text.startIndex

        while index < text.endIndex {
            let contextName = contextStack.last ?? "Normal"
            let context = definition.contexts[contextName] ?? definition.contexts["Normal"]

            if text[index].isNewline {
                let nextIndex = text.index(after: index)
                applyTransition(context?.lineEndContext, stack: &contextStack)
                index = nextIndex
                continue
            }

            if let match = matchRule(context?.rules ?? [], in: text, at: index) {
                spans.append(HighlightSpan(
                    range: index..<match.endIndex,
                    token: token(for: match.attribute)
                ))
                applyTransition(match.context, stack: &contextStack)
                index = match.endIndex
            } else if let context, context.name != "Normal" {
                let nextIndex = text.index(after: index)
                spans.append(HighlightSpan(
                    range: index..<nextIndex,
                    token: token(for: context.attribute)
                ))
                index = nextIndex
            } else {
                index = text.index(after: index)
            }
        }

        return spans
    }

    private func matchRule(_ rules: [KateRule], in text: String, at index: String.Index) -> RuleMatch? {
        for rule in rules {
            switch rule.kind {
            case .detectChar(let char):
                if text[index] == char {
                    return RuleMatch(
                        endIndex: text.index(after: index),
                        attribute: rule.attribute,
                        context: rule.context
                    )
                }
            case .detect2Chars(let char, let char1):
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[index] == char, text[nextIndex] == char1 {
                    return RuleMatch(
                        endIndex: text.index(after: nextIndex),
                        attribute: rule.attribute,
                        context: rule.context
                    )
                }
            case .keyword(let listName):
                if let match = keywordMatch(listName: listName, in: text, at: index) {
                    return RuleMatch(endIndex: match, attribute: rule.attribute, context: rule.context)
                }
            case .regex(let regex):
                if let match = regexMatch(regex, in: text, at: index) {
                    return RuleMatch(endIndex: match, attribute: rule.attribute, context: rule.context)
                }
            case .hlCStringChar:
                if text[index] == "\\" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex {
                        return RuleMatch(
                            endIndex: text.index(after: nextIndex),
                            attribute: rule.attribute,
                            context: rule.context
                        )
                    }
                }
            }
        }
        return nil
    }

    private func keywordMatch(listName: String, in text: String, at index: String.Index) -> String.Index? {
        guard isIdentifierStart(text[index]) else { return nil }
        var end = text.index(after: index)
        while end < text.endIndex, isIdentifierContinue(text[end]) {
            end = text.index(after: end)
        }
        let word = String(text[index..<end])
        return definition.lists[listName]?.contains(word) == true ? end : nil
    }

    private func regexMatch(_ regex: NSRegularExpression, in text: String, at index: String.Index) -> String.Index? {
        let nsRange = NSRange(index..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              match.range.location == nsRange.location,
              match.range.length > 0,
              let range = Range(match.range, in: text) else {
            return nil
        }
        return range.upperBound
    }

    private func applyTransition(_ transition: String?, stack: inout [String]) {
        guard let transition, transition != "#stay" else { return }
        if transition == "#pop" {
            if stack.count > 1 {
                stack.removeLast()
            }
        } else if definition.contexts[transition] != nil {
            stack.append(transition)
        }
    }

    private func token(for attribute: String) -> HighlightToken {
        definition.itemData[attribute] ?? .plainText
    }

    private func isIdentifierStart(_ character: Character) -> Bool {
        character == "_" || character.isLetter
    }

    private func isIdentifierContinue(_ character: Character) -> Bool {
        character == "_" || character.isLetter || character.isNumber
    }
}

private struct RuleMatch {
    let endIndex: String.Index
    let attribute: String
    let context: String?
}

private enum KateXMLSyntaxError: Error {
    case invalidXML
}

private extension HighlightToken {
    init(kateStyle: String) {
        switch kateStyle {
        case "dsComment":
            self = .comment
        case "dsString", "dsChar":
            self = .string
        case "dsKeyword":
            self = .keyword
        case "dsDecVal", "dsBaseN", "dsFloat":
            self = .number
        case "dsDataType":
            self = .type
        case "dsFunction":
            self = .function
        case "dsOperator":
            self = .operatorToken
        default:
            self = .plainText
        }
    }
}
