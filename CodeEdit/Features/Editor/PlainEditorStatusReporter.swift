import Foundation
import CodeEditLanguages

enum PlainEditorStatusReporter {
    static func cursorLabel(text: String, selection: NSRange) -> String {
        let nsText = text as NSString
        let cappedLocation = max(0, min(selection.location, nsText.length))
        let lineRange = nsText.lineRange(for: NSRange(location: cappedLocation, length: 0))
        let lineNumber = nsText.substring(to: cappedLocation).components(separatedBy: .newlines).count
        let currentLine = nsText.substring(with: lineRange)
        let column = currentLine.prefix(max(0, cappedLocation - lineRange.location)).count + 1
        return "\(lineNumber)/\(nsText.components(separatedBy: .newlines).count):\(column)"
    }

    static func wordCount(in text: String) -> Int {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "_" }.count
    }

    static func indentationLabel(in text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let sample = lines.prefix(50)
        var tabCount = 0
        var spaceCounts: [Int: Int] = [:]

        for line in sample {
            if line.hasPrefix("\t") {
                tabCount += 1
            } else if let count = line.prefix(while: { $0 == " " }).count.nonZero {
                spaceCounts[count, default: 0] += 1
            }
        }

        if tabCount > spaceCounts.values.reduce(0, +) {
            return "Tabs"
        }

        if let best = spaceCounts.max(by: { $0.value < $1.value })?.key {
            return "Soft Tabs: \(best)"
        }

        return "Unknown"
    }

    static func lineEndingLabel(in text: String) -> String {
        if text.contains("\r\n") {
            return "CRLF"
        } else if text.contains("\r") {
            return "CR"
        } else if text.contains("\n") {
            return "LF"
        } else {
            return "Unknown"
        }
    }

    static func encodingLabel(_ encoding: FileEncoding?) -> String {
        // A nil source encoding means no supported decoding was applied. Report "Unknown" here
        // so the status bar never claims an encoding the file was not actually read with.
        guard let encoding else {
            return "Unknown"
        }

        switch encoding {
        case .utf8:
            return "UTF-8"
        case .utf16BE:
            return "UTF-16 BE"
        case .utf16LE:
            return "UTF-16 LE"
        case .windows1252:
            return "Windows-1252"
        case .latin1:
            return "ISO Latin-1"
        }
    }

    static func languageLabel(_ language: CodeLanguage) -> String {
        switch language.id {
        case .markdown, .markdownInline:
            return "Markdown"
        case .json:
            return "JSON"
        case .yaml:
            return "YAML"
        case .swift:
            return "Swift"
        case .plainText:
            return "Plain Text"
        default:
            return language.tsName.capitalized
        }
    }
}

private extension Int {
    var nonZero: Int? {
        self == 0 ? nil : self
    }
}
