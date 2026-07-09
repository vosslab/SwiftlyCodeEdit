import CodeEditHighlighting
import Testing
@testable import CodeEditSyntaxDefinitions

@Suite("Kate context rule interpreter")
struct KateContextRuleInterpreterTests {
    @Test
    func popBangContextReplacesOnlyTheTopOfTheStack() {
        // Context "A" pushes "B" on "start", "B" pushes "D" on "enterD",
        // "D" pops itself and pushes "C" via "#pop!C" on "trigger",
        // and "C" pops back to whatever sits below it via a bare "#pop" on "back".
        // If "#pop!C" popped more than one level, the "back" span below would
        // land in "A" instead of "B".
        let contextA = SyntaxContext(
            name: "A",
            items: [.rule(SyntaxRule(pattern: "start", token: .plainText, context: "B"))]
        )
        let contextB = SyntaxContext(
            name: "B",
            attribute: "InB",
            items: [.rule(SyntaxRule(pattern: "enterD", token: .plainText, context: "D"))]
        )
        let contextD = SyntaxContext(
            name: "D",
            attribute: "InD",
            items: [.rule(SyntaxRule(pattern: "trigger", token: .plainText, context: "#pop!C"))]
        )
        let contextC = SyntaxContext(
            name: "C",
            attribute: "InC",
            items: [.rule(SyntaxRule(pattern: "back", token: .plainText, context: "#pop"))]
        )
        let definition = SyntaxDefinition(
            language: "PopBangFixture",
            rootContext: "A",
            contexts: ["A": contextA, "B": contextB, "D": contextD, "C": contextC],
            rules: []
        )

        // Markers "Z", "Y", "X", "W" are chosen because none of them appear
        // inside "start", "enterD", "trigger", or "back", so each marker's
        // style reflects only whichever context is active at that position.
        let text = "startZenterDYtriggerXbackW"
        let spans = KateContextRuleInterpreter.highlightSpans(text: text, definition: definition)

        #expect(styleName(for: "Z", in: text, spans: spans) == "InB")
        #expect(styleName(for: "Y", in: text, spans: spans) == "InD")
        #expect(styleName(for: "X", in: text, spans: spans) == "InC")
        #expect(styleName(for: "W", in: text, spans: spans) == "InB")
    }

    @Test
    func stepBudgetTruncatesRatherThanHangingOnAZeroWidthLookAheadCycle() {
        // Both contexts fire a look-ahead rule that changes the context stack
        // without ever advancing the scan index, so the evaluator bounces
        // between "Ping" and "Pong" forever unless the step budget cuts it off.
        let contextPing = SyntaxContext(
            name: "Ping",
            items: [
                .rule(SyntaxRule(pattern: "x", token: .plainText, context: "Pong", lookAhead: true))
            ]
        )
        let contextPong = SyntaxContext(
            name: "Pong",
            items: [
                .rule(SyntaxRule(pattern: "x", token: .plainText, context: "#pop", lookAhead: true))
            ]
        )
        let contextTail = SyntaxContext(
            name: "Tail",
            items: [
                .rule(SyntaxRule(pattern: "MARKER", token: .keyword, styleName: "Marker"))
            ]
        )
        let definition = SyntaxDefinition(
            language: "StepBudgetFixture",
            rootContext: "Ping",
            contexts: ["Ping": contextPing, "Pong": contextPong, "Tail": contextTail],
            rules: []
        )

        // "Tail" is unreachable from this definition; its presence only proves
        // that the scan below never advances past the stuck "x" to notice it.
        let text = "xMARKER"
        let spans = KateContextRuleInterpreter.highlightSpans(text: text, definition: definition)

        #expect(spans.isEmpty)
    }

    private func styleName(
        for needle: String,
        in text: String,
        spans: [HighlightSpan]
    ) -> String? {
        guard let range = text.range(of: needle) else {
            return nil
        }
        return spans.first { $0.range.overlaps(range) }?.styleName
    }
}
