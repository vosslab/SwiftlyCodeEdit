//
//  PlainSyntaxHighlighterTests.swift
//  CodeEditTests
//
//  Created by Codex on 2026-07-07.
//

import AppKit
import CodeEditHighlighting
import CodeEditLanguages
import Foundation
import Testing
@testable import CodeEditSyntaxDefinitions
@testable import CodeEdit

@Suite
struct PlainSyntaxHighlighterTests {
    @Test
    @MainActor
    func swiftKeywordsReceiveSyntaxColoring() async {
        let source = "struct Sample {\n    let value = \"hello\"\n}\n"
        let storage = NSTextStorage(string: source)

        PlainSyntaxHighlighter.highlight(storage: storage, language: .swift)

        // Highlighting computes off-main and hops back to apply, so poll the main
        // actor until the storage carries more than the base color, bounded so a
        // regression fails instead of hanging. Asserting only storage.length let
        // this test keep passing once coloring became async and stopped applying.
        for _ in 0..<250 {
            if distinctForegroundColorCount(in: storage) >= 2 {
                break
            }
            try? await Task.sleep(for: .milliseconds(20))
        }

        #expect(storage.length == source.count)
        // More than one distinct foreground color proves span colors were applied
        // on top of the base color, not that the request was silently dropped.
        #expect(distinctForegroundColorCount(in: storage) >= 2)
    }

    @Test
    func highlightedSpansComeFromLoadedRules() {
        let spans = CodeEditSyntaxDefinitions.highlightSpans(text: "let value = 1", language: "swift")

        #expect(spans.contains(where: { $0.token == .keyword }))
        #expect(spans.contains(where: { $0.token == .number }))
    }

    @Test
    func swiftHighlightingKeepsRulesScopedToKateContexts() {
        let text = """
        import Foundation

        struct SyntaxSmokeSample {
            let count: Int = 42
            let message: String = "hello, world"

            func compute(value: Double) -> Double {
                return value * 3.14 + Double(count)
            }
        }
        """
        let spans = CodeEditSyntaxDefinitions.highlightSpans(text: text, language: "swift")

        #expect(styleName(for: "import", in: text, spans: spans) == "Keyword")
        #expect(styleName(for: "Foundation", in: text, spans: spans) == "Imports")
        #expect(styleName(for: "Double", in: text, spans: spans) == "Data Type")
        #expect(styleName(for: "compute", in: text, spans: spans) == "Function")
        #expect(styleName(for: "\"hello, world\"", in: text, spans: spans) == "String")
        #expect(styleName(for: "42", in: text, spans: spans) == "Decimal")
        #expect(styleName(for: "3.14", in: text, spans: spans) == "Float")
        #expect(styleName(for: "Foundation", in: text, spans: spans) != "String")
        #expect(styleName(for: "SyntaxSmokeSample", in: text, spans: spans) != "String")
    }

    @Test
    func commonLanguagesResolveFromTheImportedCorpus() {
        let bashSpans = CodeEditSyntaxDefinitions.highlightSpans(text: "echo $HOME", language: "bash")
        let jsonSpans = CodeEditSyntaxDefinitions.highlightSpans(text: "{\"value\": 1}", language: "json")
        let yamlSpans = CodeEditSyntaxDefinitions.highlightSpans(text: "key: value", language: "yaml")
        let swiftSpans = CodeEditSyntaxDefinitions.highlightSpans(text: "let value = 1", language: "swift")

        #expect(!bashSpans.isEmpty)
        #expect(!jsonSpans.isEmpty)
        #expect(!yamlSpans.isEmpty)
        #expect(!swiftSpans.isEmpty)
    }

    @Test
    func numericXmlEntitiesInVendoredDefinitionsStillMatchText() {
        let spans = CodeEditSyntaxDefinitions.highlightSpans(text: "value \u{225C} rule", language: "bnf")

        #expect(spans.contains(where: { $0.styleName == "Copulae" }))
    }

    @Test
    func ruleConstraintsStayAlignedWithLoadedDefinitions() {
        let multiline = "    # heading\nvalue = \"a\"\n"
        let markdownSpans = CodeEditSyntaxDefinitions.highlightSpans(text: multiline, language: "markdown")
        let swiftSpans = CodeEditSyntaxDefinitions.highlightSpans(text: "let value = \"a\"", language: "swift")

        #expect(!markdownSpans.isEmpty)
        #expect(swiftSpans.contains(where: { $0.styleName == "String" }))
    }

    // Two documents highlight concurrently: with the old single shared
    // generation counter, the second storage's request bumped the global
    // generation and stranded the first storage's in-flight result at the
    // post-compute guard, so one window stayed plain text. With per-storage
    // state neither request can invalidate the other, so both end up colored.
    @Test
    @MainActor
    func twoDocumentsBothReceiveHighlightingConcurrently() async {
        let firstStorage = NSTextStorage(string: "struct First {\n    let value = \"alpha\"\n}\n")
        let secondStorage = NSTextStorage(string: "enum Second {\n    case beta\n    let count = 7\n}\n")

        // Schedule both before either background pass can finish, reproducing
        // the two-window race where one request would strand the other.
        PlainSyntaxHighlighter.highlight(storage: firstStorage, language: .swift)
        PlainSyntaxHighlighter.highlight(storage: secondStorage, language: .swift)

        // Both computes run off-main and hop back to apply. Yield the main actor
        // until both storages carry more than the base color, bounded so a
        // regression fails instead of hanging.
        for _ in 0..<250 {
            if distinctForegroundColorCount(in: firstStorage) >= 2,
               distinctForegroundColorCount(in: secondStorage) >= 2 {
                break
            }
            try? await Task.sleep(for: .milliseconds(20))
        }

        // More than one distinct foreground color proves span colors were
        // applied on top of the base color, not that the request was dropped.
        #expect(distinctForegroundColorCount(in: firstStorage) >= 2)
        #expect(distinctForegroundColorCount(in: secondStorage) >= 2)
    }

    @MainActor
    private func distinctForegroundColorCount(in storage: NSTextStorage) -> Int {
        var colors: Set<NSColor> = []
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.foregroundColor, in: fullRange) { value, _, _ in
            if let color = value as? NSColor {
                colors.insert(color)
            }
        }
        return colors.count
    }

    private func styleName(for snippet: String, in text: String, spans: [HighlightSpan]) -> String? {
        guard let snippetRange = text.range(of: snippet) else {
            return nil
        }
        return spans.first { $0.range.overlaps(snippetRange) }?.styleName
    }
}
