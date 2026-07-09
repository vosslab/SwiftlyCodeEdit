//
//  FileEncoding.swift
//  CodeEdit
//
//  Created by Khan Winter on 5/31/24.
//

import Foundation

enum FileEncoding: CaseIterable {
    case utf8
    case utf16BE
    case utf16LE
    // Single-byte legacy encodings. Ordered after the Unicode cases so the
    // detector prefers Unicode when the bytes are valid Unicode. Windows-1252
    // comes before Latin-1 because its 0x80-0x9F range carries printable text
    // (smart quotes, euro) that Latin-1 would decode as C1 control characters.
    case windows1252
    case latin1

    var nsValue: UInt {
        switch self {
        case .utf8:
            return NSUTF8StringEncoding
        case .utf16BE:
            return NSUTF16BigEndianStringEncoding
        case .utf16LE:
            return NSUTF16LittleEndianStringEncoding
        case .windows1252:
            return NSWindowsCP1252StringEncoding
        case .latin1:
            return NSISOLatin1StringEncoding
        }
    }

    init?(_ int: UInt) {
        switch int {
        case NSUTF8StringEncoding:
            self = .utf8
        case NSUTF16BigEndianStringEncoding:
            self = .utf16BE
        case NSUTF16LittleEndianStringEncoding:
            self = .utf16LE
        case NSWindowsCP1252StringEncoding:
            self = .windows1252
        case NSISOLatin1StringEncoding:
            self = .latin1
        default:
            return nil
        }
    }
}
