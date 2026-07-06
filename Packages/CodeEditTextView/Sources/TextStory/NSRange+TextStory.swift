//
//  NSRange+TextStory.swift
//  TextStory
//
//  Created by Codex on 2026-07-06.
//

import Foundation

public extension NSRange {
    static let notFound = NSRange(location: NSNotFound, length: 0)

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
        let lower = min(max(location, 0), length)
        let upper = min(max(location + self.length, lower), length)
        return NSRange(location: lower, length: upper - lower)
    }
}
