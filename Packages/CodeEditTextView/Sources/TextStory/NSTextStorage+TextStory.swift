//
//  NSTextStorage+TextStory.swift
//  TextStory
//
//  Created by Codex on 2026-07-06.
//

import AppKit

public extension NSTextStorage {
    func substring(from range: NSRange) -> String? {
        guard NSLocationInRange(range.location, NSRange(location: 0, length: length)),
              range.location + range.length <= length else {
            return nil
        }
        return (string as NSString).substring(with: range)
    }

    func inverseMutation(for mutation: TextMutation) -> TextMutation {
        let replacement = (string as NSString).substring(with: mutation.range)
        return TextMutation(string: replacement, range: NSRange(location: mutation.range.location, length: mutation.string.utf16.count), limit: length)
    }

    func findPrecedingOccurrenceOfCharacter(in characterSet: CharacterSet, from position: Int) -> Int? {
        guard position > 0, position <= length else { return nil }
        let nsString = string as NSString
        var index = position - 1
        while index >= 0 {
            let charRange = NSRange(location: index, length: 1)
            if let scalar = nsString.substring(with: charRange).unicodeScalars.first,
               characterSet.contains(scalar) {
                index -= 1
                continue
            }
            return index + 1
        }
        return 0
    }

    func findNextOccurrenceOfCharacter(in characterSet: CharacterSet, from position: Int) -> Int? {
        guard position >= 0, position < length else { return nil }
        let nsString = string as NSString
        var index = position
        while index < length {
            let charRange = NSRange(location: index, length: 1)
            if let scalar = nsString.substring(with: charRange).unicodeScalars.first,
               characterSet.contains(scalar) {
                index += 1
                continue
            }
            return index
        }
        return length
    }
}
