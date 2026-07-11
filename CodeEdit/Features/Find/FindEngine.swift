//
//  FindEngine.swift
//  SwiftlyCodeEdit
//
//  Pure search logic for the find panel. Harvested behavior from the old
//  CodeEditSourceEditor find panel (FindPanelViewModel+Find), but with no dependency
//  on TextViewController: it takes a plain String and returns match ranges, so it can
//  be unit-tested without a live editor. The panel model drives selection and undo;
//  this type only answers "where does the query match".
//

import Foundation

/// How a literal query is turned into a search pattern. `regularExpression` uses the
/// query verbatim; every other case escapes the query and adds the appropriate
/// anchors, so literal searches never treat user input as regex metacharacters.
enum FindMethod: CaseIterable {
    case contains
    case matchesWord
    case startsWith
    case endsWith
    case regularExpression

    var displayName: String {
        switch self {
        case .contains:
            return "Contains"
        case .matchesWord:
            return "Matches Word"
        case .startsWith:
            return "Starts With"
        case .endsWith:
            return "Ends With"
        case .regularExpression:
            return "Regular Expression"
        }
    }
}

/// The one failure a search can report: a `regularExpression` query that does not
/// compile. Literal methods escape their input and so never fail this way.
enum FindError: Error, Equatable {
    case invalidRegularExpression
}

/// Stateless search over document text. All entry points are pure functions of their
/// arguments so the panel model's behavior is verifiable without AppKit.
enum FindEngine {
    /// Finds every non-empty, non-overlapping match of `query` in `text`.
    ///
    /// - Returns: `.success` with match ranges (empty when the query is empty or has
    ///   no matches), or `.failure(.invalidRegularExpression)` when `method` is
    ///   `regularExpression` and `query` does not compile. `NSRegularExpression`
    ///   already yields non-overlapping matches left to right, which the replace path
    ///   relies on.
    static func findMatches(
        in text: String,
        query: String,
        method: FindMethod,
        matchCase: Bool
    ) -> Result<[NSRange], FindError> {
        guard !query.isEmpty else {
            return .success([])
        }

        // Case sensitivity is off by default; regex mode also lets `.` span newlines
        // and anchors match line boundaries, matching the old panel's behavior.
        var options: NSRegularExpression.Options = matchCase ? [] : [.caseInsensitive]
        if method == .regularExpression {
            options.insert(.dotMatchesLineSeparators)
            options.insert(.anchorsMatchLines)
        }

        let pattern = self.pattern(for: query, method: method)

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return .failure(.invalidRegularExpression)
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        // Zero-length matches (an empty-anchor regex, for instance) are dropped so a
        // "match" is always a real span the user can select and replace.
        let ranges = regex.matches(in: text, range: fullRange)
            .map(\.range)
            .filter { $0.length > 0 }
        return .success(ranges)
    }

    /// Builds the regex pattern for a query under a given method. Literal methods
    /// escape the query so metacharacters stay literal; regex mode passes it through.
    private static func pattern(for query: String, method: FindMethod) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: query)
        switch method {
        case .contains:
            return escaped
        case .matchesWord:
            return "\\b" + escaped + "\\b"
        case .startsWith:
            return "(?:^|\\b)" + escaped
        case .endsWith:
            return escaped + "(?:$|\\b)"
        case .regularExpression:
            return query
        }
    }

    /// Index of the match nearest `cursorLocation`, used to pick the starting match
    /// when a search runs. Returns nil when there are no matches. Matches are ordered
    /// by location, so a binary search finds the closest start position.
    static func nearestMatchIndex(to cursorLocation: Int, in matches: [NSRange]) -> Int? {
        guard !matches.isEmpty else { return nil }

        var left = 0
        var right = matches.count - 1
        var bestIndex = -1
        var bestDiff = Int.max

        while left <= right {
            let mid = left + (right - left) / 2
            let midStart = matches[mid].location
            let diff = abs(midStart - cursorLocation)

            if diff == 0 {
                return mid
            }
            if diff < bestDiff {
                bestDiff = diff
                bestIndex = mid
            }
            if midStart < cursorLocation {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }

        return bestIndex >= 0 ? bestIndex : nil
    }
}
