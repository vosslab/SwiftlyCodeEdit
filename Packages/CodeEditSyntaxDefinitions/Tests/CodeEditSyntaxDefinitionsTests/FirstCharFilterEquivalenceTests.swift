import Foundation
import CodeEditHighlighting
import Testing
@testable import CodeEditSyntaxDefinitions

// The leading-character prefilter is only sound if it never changes output: it
// may skip a regex only when that regex provably cannot match at the position.
// These tests load real vendored definitions and assert the interpreter emits
// byte-for-byte identical spans with the filter on and off, across several
// languages and content shapes (keywords, numbers, strings, comments, unicode).
@Suite("First-char filter equivalence")
struct FirstCharFilterEquivalenceTests {
    private func definition(named name: String) throws -> SyntaxDefinition {
        let xml = try CodeEditSyntaxDefinitions.kateDefinitionXML(named: name)
        return try #require(CodeEditSyntaxDefinitions.parseDefinition(kateXML: xml))
    }

    private func assertFilterMatchesUnfiltered(definitionName: String, text: String) throws {
        let definition = try definition(named: definitionName)
        // Compare at the interpretation-stage boundary (token runs) so the check
        // targets exactly what the prefilter affects, then confirm the span-mapping
        // stage preserves the equivalence too.
        let filteredRuns = KateContextRuleInterpreter.tokenRuns(
            text: text,
            definition: definition,
            applyFirstCharFilter: true
        )
        let unfilteredRuns = KateContextRuleInterpreter.tokenRuns(
            text: text,
            definition: definition,
            applyFirstCharFilter: false
        )
        #expect(filteredRuns == unfilteredRuns)
        // Guard against a degenerate "both empty" pass.
        #expect(!unfilteredRuns.isEmpty)

        let filteredSpans = CodeEditSyntaxDefinitions.spans(from: filteredRuns, in: text)
        let unfilteredSpans = CodeEditSyntaxDefinitions.spans(from: unfilteredRuns, in: text)
        #expect(filteredSpans == unfilteredSpans)
    }

    @Test
    func swiftSpansAreIdenticalWithAndWithoutTheFilter() throws {
        let text = """
        import Foundation

        struct SyntaxSmokeSample {
            let count: Int = 42
            let hexValue = 0xFF
            let ratio: Double = 3.14
            let message: String = "hello, world \\u{2116}"
            // trailing comment with symbols: <>?@
            func compute(value: Double) -> Double {
                return value * 3.14 + Double(count)
            }
        }
        """
        try assertFilterMatchesUnfiltered(definitionName: "swift", text: text)
    }

    @Test
    func otherLanguagesAreIdenticalWithAndWithoutTheFilter() throws {
        try assertFilterMatchesUnfiltered(definitionName: "bash", text: "echo $HOME # comment\nls -la\n")
        try assertFilterMatchesUnfiltered(definitionName: "json", text: "{\"value\": 1, \"name\": \"x\"}")
        try assertFilterMatchesUnfiltered(definitionName: "yaml", text: "key: value\nlist:\n  - one\n  - two\n")
        try assertFilterMatchesUnfiltered(definitionName: "markdown", text: "# Heading\n\nBody with `code` and text.\n")
        try assertFilterMatchesUnfiltered(definitionName: "python", text: "def add(a, b):\n    return a + b  # sum\n")
    }

    // Definitions whose rules use POSIX bracket classes ([[:cntrl:]], [[:graph:]]).
    // Text with control and graph characters must reach those rules identically
    // with the filter on and off; a filter that misparsed the POSIX class would
    // wrongly skip the rule and drop spans here.
    @Test
    func posixBracketDefinitionsAreIdenticalWithAndWithoutTheFilter() throws {
        let controlAndGraph = "\u{0001}\u{0002}\tprofile /bin/ls {\n  capability net_admin,\n}\n"
        try assertFilterMatchesUnfiltered(definitionName: "apparmor", text: controlAndGraph)
        try assertFilterMatchesUnfiltered(definitionName: "context", text: "\\starttext control \u{0007} graph\n")
    }

    // Direct regression for the POSIX-class false-skip: a synthetic definition
    // whose only rules are [[:cntrl:]]+ and [[:graph:]]+. With the misparse, the
    // filter excluded control bytes, so the cntrl rule was skipped on control
    // characters and the run vanished; the fix bails those rules to always-run.
    @Test
    func posixControlClassRuleFiresOnControlCharacters() throws {
        let xml = """
        <language name="PosixClassFixture" section="Test" version="1" kateversion="5.0">
          <highlighting>
            <contexts>
              <context name="Normal" attribute="Normal Text" lineEndContext="#stay">
                <RegExpr attribute="Keyword" String="[[:cntrl:]]+"/>
                <RegExpr attribute="String" String="[[:graph:]]+"/>
              </context>
            </contexts>
          </highlighting>
        </language>
        """
        let definition = try #require(CodeEditSyntaxDefinitions.parseDefinition(kateXML: xml))
        let text = "\u{0001}\u{0002}abc"

        let filtered = KateContextRuleInterpreter.tokenRuns(text: text, definition: definition, applyFirstCharFilter: true)
        let unfiltered = KateContextRuleInterpreter.tokenRuns(text: text, definition: definition, applyFirstCharFilter: false)
        #expect(filtered == unfiltered)
        // The control run must be present: a leading Keyword run covering the two
        // control bytes proves the [[:cntrl:]]+ rule was not wrongly skipped.
        #expect(filtered.contains { $0.styleName == "Keyword" && $0.location == 0 && $0.length == 2 })
    }

    // Non-ASCII fixture: surrogate-pair emoji, CJK, and a base+combining-mark
    // grapheme. Beyond filter equivalence this exercises the match-jump cursor:
    // if the grapheme cursor and its UTF-16 offset could desync on a match that
    // ends mid-cluster, spans would drift or map out of bounds. Every run must map
    // back to a valid in-bounds String.Index range.
    @Test
    func unicodeFixtureFilterEquivalenceAndValidRanges() throws {
        let text = """
        import Foundation
        // emoji \u{1F600} and cjk \u{4E2D}\u{6587} and combining e\u{0301}x
        let label = "greeting \u{1F600} \u{4E2D}\u{6587} cafe\u{0301}"
        let count = 42
        """
        let definition = try definition(named: "swift")
        let utf16Count = (text as NSString).length

        let filtered = KateContextRuleInterpreter.tokenRuns(text: text, definition: definition, applyFirstCharFilter: true)
        let unfiltered = KateContextRuleInterpreter.tokenRuns(text: text, definition: definition, applyFirstCharFilter: false)
        #expect(filtered == unfiltered)
        #expect(!filtered.isEmpty)

        // Every run stays in bounds and resolves to a real String.Index range, and
        // the span-mapping stage keeps all of them (no run dropped as unmappable).
        for run in filtered {
            #expect(run.location >= 0)
            #expect(run.location + run.length <= utf16Count)
            #expect(Range(run.nsRange, in: text) != nil)
        }
        let spans = CodeEditSyntaxDefinitions.spans(from: filtered, in: text)
        #expect(spans.count == filtered.count)
    }
}
