import AppKit
import CodeEditHighlighting
import CodeEditLanguages
import CodeEditSyntaxDefinitions
import CodeEditTextView

@MainActor
struct PlainEditorSyntaxStyler {
    private let swiftHighlighter: KateXMLSyntaxHighlighter?

    static func makeDefault() -> PlainEditorSyntaxStyler {
        let highlighter: KateXMLSyntaxHighlighter?
        do {
            highlighter = try KateXMLSyntaxHighlighter(
                definitionXML: CodeEditSyntaxDefinitions.kateDefinitionXML(named: "swift")
            )
        } catch {
            highlighter = nil
            #if DEBUG
            debugRuntimeLog("Plain editor Swift syntax highlighter unavailable: \(error)")
            #endif
        }
        return PlainEditorSyntaxStyler(swiftHighlighter: highlighter)
    }

    func apply(to textView: TextView, document: CodeFileDocument) {
        guard document.getLanguage().id == .swift,
              let swiftHighlighter else {
            return
        }

        let text = textView.textStorage.string
        guard !text.isEmpty else { return }

        let spans = swiftHighlighter.highlight(
            text: text,
            language: "Swift",
            visibleRange: text.startIndex..<text.endIndex,
            editRange: nil
        )
        apply(spans: spans, to: textView)

        #if DEBUG
        logTokenSummary(spans: spans, in: textView.textStorage)
        #endif
    }

    private func apply(spans: [HighlightSpan], to textView: TextView) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(textView.typingAttributes, range: fullRange)

        for span in spans {
            let range = NSRange(span.range, in: storage.string)
            storage.addAttributes(attributes(for: span.token, baseFont: textView.font), range: range)
        }

        storage.endEditing()
        textView.needsDisplay = true
        textView.layoutManager?.setNeedsLayout()
    }

    private func attributes(for token: HighlightToken, baseFont: NSFont) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color(for: token),
            .font: baseFont
        ]

        if token == .keyword || token == .type {
            attributes[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        }

        return attributes
    }

    private func color(for token: HighlightToken) -> NSColor {
        switch token {
        case .comment:
            return .systemGreen
        case .string:
            return .systemRed
        case .keyword:
            return .systemBlue
        case .number:
            return .systemPurple
        case .type:
            return .systemTeal
        case .function:
            return .systemIndigo
        case .operatorToken:
            return .systemOrange
        case .markup:
            return .systemBrown
        case .plainText:
            return .textColor
        }
    }

    #if DEBUG
    private func logTokenSummary(spans: [HighlightSpan], in storage: NSTextStorage) {
        let tokens = Set(spans.map(\.token))
        let tokenNames = tokens.map(String.init(describing:)).sorted()
        let colorCount = distinctForegroundColorCount(in: storage)
        debugRuntimeLog(
            "Plain editor Swift syntax highlight: tokens=\(tokenNames.joined(separator: ",")) colors=\(colorCount)"
        )
    }

    private func distinctForegroundColorCount(in storage: NSTextStorage) -> Int {
        var colors: Set<String> = []
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.foregroundColor, in: fullRange) { value, _, _ in
            guard let color = value as? NSColor else { return }
            colors.insert(color.description)
        }
        return colors.count
    }
    #endif
}
