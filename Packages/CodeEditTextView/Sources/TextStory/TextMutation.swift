//
//  TextMutation.swift
//  TextStory
//
//  Created by Codex on 2026-07-06.
//

import Foundation
import AppKit

public struct TextMutation: Hashable, Sendable {
    public var string: String
    public var range: NSRange
    public var limit: Int

    public init(string: String, range: NSRange, limit: Int) {
        self.string = string
        self.range = range
        self.limit = limit
    }

    public var delta: Int {
        string.utf16.count - range.length
    }

    public var inverseDelta: Int {
        -delta
    }

    public var inverseRange: NSRange {
        NSRange(location: range.location, length: string.utf16.count)
    }
}

public struct RangeMutation: Sendable {
    public var range: NSRange
    public var delta: Int

    public init(range: NSRange, delta: Int) {
        self.range = range
        self.delta = delta
    }

    public func transform(range target: NSRange) -> NSRange? {
        let lowerBound = target.location
        let upperBound = target.location + target.length
        let mutationLower = range.location
        let mutationUpper = range.location + range.length

        if target.length == 0 {
            if target.location < mutationLower {
                return target
            }
            if target.location > mutationUpper {
                return NSRange(location: target.location + delta, length: 0)
            }
            return NSRange(location: mutationLower + delta, length: 0)
        }

        if upperBound <= mutationLower {
            return target
        }

        if lowerBound >= mutationUpper {
            let shifted = NSRange(location: lowerBound + delta, length: target.length)
            return shifted
        }

        let newLower = min(lowerBound, mutationLower)
        let newUpper = max(upperBound + delta, mutationLower)
        guard newUpper >= newLower else { return nil }
        return NSRange(location: newLower, length: newUpper - newLower)
    }
}
