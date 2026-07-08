import Testing
@testable import CodeEditHighlighting

@Suite("Kate XML syntax highlighter")
struct KateXMLSyntaxHighlighterTests {
    private let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <language name="Swift">
      <highlighting>
        <list name="keywords">
          <item>let</item>
          <item>return</item>
        </list>
        <contexts>
          <context name="Normal" attribute="Normal Text" lineEndContext="#stay">
            <Detect2Chars char="/" char1="/" attribute="Comment" context="Line Comment"/>
            <Detect2Chars char="/" char1="*" attribute="Comment" context="Block Comment"/>
            <DetectChar char="&quot;" attribute="String" context="String"/>
            <RegExpr String="\\b[0-9]+\\b" attribute="Number"/>
            <keyword String="keywords" attribute="Keyword"/>
            <RegExpr String="\\b[A-Z][A-Za-z0-9_]*\\b" attribute="Type"/>
          </context>
          <context name="Line Comment" attribute="Comment" lineEndContext="#pop"/>
          <context name="Block Comment" attribute="Comment" lineEndContext="#stay">
            <Detect2Chars char="*" char1="/" attribute="Comment" context="#pop"/>
          </context>
          <context name="String" attribute="String" lineEndContext="#pop">
            <HlCStringChar attribute="String"/>
            <DetectChar char="&quot;" attribute="String" context="#pop"/>
          </context>
        </contexts>
      </highlighting>
      <itemDatas>
        <itemData name="Keyword" defStyleNum="dsKeyword"/>
        <itemData name="Comment" defStyleNum="dsComment"/>
        <itemData name="String" defStyleNum="dsString"/>
        <itemData name="Number" defStyleNum="dsDecVal"/>
        <itemData name="Type" defStyleNum="dsDataType"/>
      </itemDatas>
    </language>
    """

    @Test func contextRulesPreventKeywordsInsideCommentsAndStrings() throws {
        let highlighter = try KateXMLSyntaxHighlighter(definitionXML: xml)
        let text = """
        let value = 42 // return String
        let name = "return 7"
        """

        let spans = highlighter.highlight(
            text: text,
            language: "Swift",
            visibleRange: text.startIndex..<text.endIndex,
            editRange: nil
        )

        #expect(tokens(for: "let", in: text, spans: spans) == [.keyword, .keyword])
        #expect(tokens(for: "42", in: text, spans: spans) == [.number])
        #expect(tokens(for: "return", in: text, spans: spans) == [.comment, .string])
        #expect(tokens(for: "String", in: text, spans: spans) == [.comment])
    }

    @Test func blockCommentContextPopsBackToNormalRules() throws {
        let highlighter = try KateXMLSyntaxHighlighter(definitionXML: xml)
        let text = """
        /* return 123 String */
        let value = 42
        """

        let spans = highlighter.highlight(
            text: text,
            language: "Swift",
            visibleRange: text.startIndex..<text.endIndex,
            editRange: nil
        )

        #expect(tokens(for: "return", in: text, spans: spans) == [.comment])
        #expect(tokens(for: "123", in: text, spans: spans) == [.comment])
        #expect(tokens(for: "String", in: text, spans: spans) == [.comment])
        #expect(tokens(for: "let", in: text, spans: spans) == [.keyword])
        #expect(tokens(for: "42", in: text, spans: spans) == [.number])
    }

    @Test func emptyDocumentsProduceNoSpans() throws {
        let highlighter = try KateXMLSyntaxHighlighter(definitionXML: xml)
        let text = ""

        let spans = highlighter.highlight(
            text: text,
            language: "Swift",
            visibleRange: text.startIndex..<text.endIndex,
            editRange: nil
        )

        #expect(spans.isEmpty)
    }

    @Test func languageMismatchFallsBackToPlainText() throws {
        let highlighter = try KateXMLSyntaxHighlighter(definitionXML: xml)
        let text = "let value = 42"

        let spans = highlighter.highlight(
            text: text,
            language: "Markdown",
            visibleRange: text.startIndex..<text.endIndex,
            editRange: nil
        )

        #expect(spans.isEmpty)
    }

    @Test func rehighlightingReflectsTextChanges() throws {
        let highlighter = try KateXMLSyntaxHighlighter(definitionXML: xml)
        let originalText = "let value = 42"
        let editedText = "let name = \"return 7\""

        let originalSpans = highlighter.highlight(
            text: originalText,
            language: "Swift",
            visibleRange: originalText.startIndex..<originalText.endIndex,
            editRange: nil
        )
        let editedSpans = highlighter.highlight(
            text: editedText,
            language: "Swift",
            visibleRange: editedText.startIndex..<editedText.endIndex,
            editRange: nil
        )

        #expect(tokens(for: "42", in: originalText, spans: originalSpans) == [.number])
        #expect(tokens(for: "return", in: editedText, spans: editedSpans) == [.string])
        #expect(Set(originalSpans.map(\.token)) != Set(editedSpans.map(\.token)))
    }

    private func tokens(
        for needle: String,
        in text: String,
        spans: [HighlightSpan]
    ) -> [HighlightToken] {
        var tokens: [HighlightToken] = []
        var searchStart = text.startIndex
        while let range = text.range(of: needle, range: searchStart..<text.endIndex) {
            if let token = spans.first(where: { $0.range.overlaps(range) })?.token {
                tokens.append(token)
            }
            searchStart = range.upperBound
        }
        return tokens
    }
}
