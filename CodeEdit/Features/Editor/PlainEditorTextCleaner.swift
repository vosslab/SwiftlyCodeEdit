enum PlainEditorTextCleaner {
    static func trimTrailingHorizontalWhitespace(in text: String) -> String {
        var output = ""
        var line = ""

        // Iterate by unicode scalar, not Character: Swift merges a "\r\n"
        // pair into a single extended grapheme cluster, which would never
        // match a bare "\n" or "\r" comparison and would leave CRLF-ended
        // lines completely untrimmed.
        for scalar in text.unicodeScalars {
            if scalar == "\n" || scalar == "\r" {
                output += line.trimmingTrailingSpacesAndTabs()
                output.unicodeScalars.append(scalar)
                line = ""
            } else {
                line.unicodeScalars.append(scalar)
            }
        }

        output += line.trimmingTrailingSpacesAndTabs()
        return output
    }
}

private extension String {
    func trimmingTrailingSpacesAndTabs() -> String {
        var result = self
        while let last = result.last, last == " " || last == "\t" {
            result.removeLast()
        }
        return result
    }
}
