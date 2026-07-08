enum PlainEditorTextCleaner {
    static func trimTrailingHorizontalWhitespace(in text: String) -> String {
        var output = ""
        var line = ""

        for character in text {
            if character == "\n" || character == "\r" {
                output += line.trimmingTrailingSpacesAndTabs()
                output.append(character)
                line = ""
            } else {
                line.append(character)
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
