//
//  NSRange+TextStory.swift
//  TextStory
//
//  Created by Codex on 2026-07-06.
//

import Foundation

public extension NSRange {
    static let notFound = NSRange(location: NSNotFound, length: 0)
    static let zero = NSRange(location: 0, length: 0)

    var max: Int {
        location + length
    }

    var isEmpty: Bool {
        length == 0
    }

    init(start: Int, end: Int) {
        self.init(location: start, length: end - start)
    }

    func shifted(by offset: Int) -> NSRange? {
        let location = self.location + offset
        guard location >= 0 else { return nil }
        return NSRange(location: location, length: length)
    }

    func clamped(to length: Int) -> NSRange {
        let safeLength = Swift.max(length, 0)
        let lower = Swift.min(Swift.max(location, 0), safeLength)
        let end = location + self.length
        let upper = Swift.min(Swift.max(end, lower), safeLength)
        return NSRange(location: lower, length: upper - lower)
    }
}
