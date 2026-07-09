import Foundation
import CodeEditHighlighting
import Testing
@testable import CodeEditSyntaxDefinitions

// Per-stage timing gate for the syntax-color pipeline. The user-visible complaint
// is that a freshly opened ~1400-line Swift file stares at plain text for several
// seconds. This suite times each display-free stage independently -- parse (XML ->
// rules), interpret (text -> token runs), span-map (runs -> spans) -- like an
// ammeter reading current at each point in the circuit, and prints two
// machine-readable lines that scripts/highlight_benchmark.sh records into
// test-results/perf/:
//   HIGHLIGHT_BENCH         end-to-end totals (cached-definition repeat-open path)
//   HIGHLIGHT_BENCH_STAGES  parseMs / interpretMs / spanMapMs breakdown
// The budget assert catches gross regressions; it is intentionally loose so slower
// machines still pass while a return of the old O(n^2) cost fails.
@Suite("Kate interpreter benchmark")
struct KateInterpreterBenchmarkTests {
    // Roughly 1400 lines of representative Swift, matching the size of the file
    // in the plain-editor smoke that produced the 6.2 s baseline.
    private static func largeSwiftFixture(targetLines: Int) -> String {
        let block = """
        import Foundation

        // MARK: - Sample type \u{2116}INDEX
        struct SampleTypeINDEX: Codable, Equatable {
            let identifier: Int = INDEX
            let title: String = "sample title INDEX"
            var isEnabled: Bool = true
            private let ratio: Double = 3.14159

            /// Computes a derived value from the stored ratio.
            func computeValueINDEX(base: Double) -> Double {
                let scaled = base * ratio + Double(identifier)
                guard scaled > 0 else { return 0.0 }
                return scaled
            }

            func describeINDEX() -> String {
                return "SampleTypeINDEX(id=\\(identifier), title=\\(title))"
            }
        }

        """
        var text = ""
        var index = 0
        while text.split(separator: "\n", omittingEmptySubsequences: false).count < targetLines {
            text += block.replacingOccurrences(of: "INDEX", with: String(index))
            index += 1
        }
        return text
    }

    private func elapsedMilliseconds(_ body: () -> Void) -> Int {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Int((DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
    }

    private func median(_ values: [Int]) -> Int {
        values.sorted()[values.count / 2]
    }

    @Test
    func coldPassStaysUnderBudget() throws {
        let text = Self.largeSwiftFixture(targetLines: 1400)
        let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
        let swiftXML = try CodeEditSyntaxDefinitions.kateDefinitionXML(named: "swift")

        // Warm the cached-definition path and the process-wide compiled-regex
        // cache so the timings below measure steady-state stage cost, matching the
        // repeat-open experience rather than one-time setup.
        _ = CodeEditSyntaxDefinitions.highlightSpans(text: "let value = 1", language: "swift")

        var totals: [Int] = []
        var parses: [Int] = []
        var interprets: [Int] = []
        var spanMaps: [Int] = []

        for _ in 0..<3 {
            // Stage 1: parse (uncached) Kate XML -> rule structures.
            var definition: SyntaxDefinition?
            parses.append(elapsedMilliseconds {
                definition = CodeEditSyntaxDefinitions.parseDefinition(kateXML: swiftXML)
            })
            let rules = try #require(definition)

            // Stage 2: interpret text + rules -> offset-native token runs.
            var runs: [TokenRun] = []
            interprets.append(elapsedMilliseconds {
                runs = CodeEditSyntaxDefinitions.tokenRuns(text: text, definition: rules)
            })
            #expect(!runs.isEmpty)

            // Stage 3: span-map token runs -> spans.
            var spans: [HighlightSpan] = []
            spanMaps.append(elapsedMilliseconds {
                spans = CodeEditSyntaxDefinitions.spans(from: runs, in: text)
            })
            #expect(!spans.isEmpty)

            // End-to-end total through the cached-definition convenience path.
            totals.append(elapsedMilliseconds {
                _ = CodeEditSyntaxDefinitions.highlightSpans(text: text, language: "swift")
            })
        }

        let sortedTotals = totals.sorted()
        let model = hardwareModel()
        print("HIGHLIGHT_BENCH lines=\(lineCount) runs=\(totals) min=\(sortedTotals.first!) median=\(median(totals)) max=\(sortedTotals.last!) model=\(model)")
        print("HIGHLIGHT_BENCH_STAGES lines=\(lineCount) parseMs=\(median(parses)) interpretMs=\(median(interprets)) spanMapMs=\(median(spanMaps)) totalMs=\(median(totals)) model=\(model)")

        // Regression gate. The optimized end-to-end pass is tens of milliseconds on
        // the reference machine; the pre-optimization O(n^2) pass was ~1100 ms in
        // the same build. An 800 ms budget leaves generous headroom for slower or
        // busier machines while still failing loudly if the quadratic step-budget
        // cost (or any similar per-step O(n) cost) is reintroduced.
        #expect(median(totals) < 800)
    }

    private func hardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
}
