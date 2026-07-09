import Foundation
import CodeEditHighlighting
import Testing
@testable import CodeEditSyntaxDefinitions

@Suite("Syntax definition repository concurrency")
struct SyntaxDefinitionRepositoryConcurrencyTests {
    // The plain editor highlights off the main thread with several detached
    // tasks that can run at once (proven by the smoke log), so many callers
    // hit SyntaxDefinitionRepository.shared concurrently. The repository lazily
    // loads definitions on first access, mutating its shared definition and
    // loaded-file caches under an internal NSLock. A highlight pass is a pure
    // function of text and definition, so a concurrent batch of calls must
    // return exactly the same spans as a serial baseline. Any lock regression
    // that let those caches be mutated from two threads at once would corrupt a
    // definition and change or drop a language's spans, failing this test.
    @Test
    func concurrentHighlightSpansMatchSerialBaseline() async {
        // Distinct languages so concurrent first-access calls race on separate
        // lazy loads rather than all reading one already-cached definition.
        let cases: [(language: String, text: String)] = [
            ("swift", "let value = 42 // note\nfunc greet() {}"),
            ("python", "def greet():\n    return 'hi'  # note"),
            ("lua", "local x = 10 -- note\nfunction f() end"),
            ("json", "{\"key\": 42, \"flag\": true}"),
            ("bash", "echo hello # note\nexport X=1"),
            ("markdown", "# Title\n\nSome **bold** text."),
            ("c", "int main(void) { return 0; } // note"),
            ("xml", "<root attr=\"1\"><child/></root>"),
        ]

        // Serial baseline: one call per language, no concurrency.
        var baselineByLanguage: [String: [String]] = [:]
        for testCase in cases {
            let spans = CodeEditSyntaxDefinitions.highlightSpans(text: testCase.text, language: testCase.language)
            baselineByLanguage[testCase.language] = spanDescriptors(spans, in: testCase.text)
        }

        // Concurrent batch: repeat each language several times so overlapping
        // first-access loads are likely to collide inside the lock.
        let concurrentResults = await withTaskGroup(of: (String, [String]).self) { group in
            for _ in 0..<4 {
                for testCase in cases {
                    group.addTask {
                        let spans = CodeEditSyntaxDefinitions.highlightSpans(text: testCase.text, language: testCase.language)
                        return (testCase.language, spanDescriptors(spans, in: testCase.text))
                    }
                }
            }
            var collected: [(String, [String])] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        // Every concurrent result must equal that language's serial baseline.
        for (language, descriptors) in concurrentResults {
            #expect(descriptors == baselineByLanguage[language])
        }
    }
}

// Reduce spans to offset/length/token/style descriptors so equality does not
// depend on String.Index identity across separate call sites.
private func spanDescriptors(_ spans: [HighlightSpan], in text: String) -> [String] {
    let descriptors = spans.map { span -> String in
        let range = NSRange(span.range, in: text)
        return "\(range.location):\(range.length):\(span.token):\(span.styleName ?? "")"
    }
    return descriptors
}
