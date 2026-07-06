//
//  SourceEditorCompatibility.swift
//  CodeEdit
//
//  Temporary compatibility shims for the plain-editor cutover.
//

import AppKit
import Foundation
import Combine
import CodeEditTextView
import CodeEditLanguages

public typealias TextViewController = TextView

public enum HighlightProvidingError: Error {
    case operationCancelled
}

public struct HighlightRange: Hashable, Sendable {
    public let range: NSRange
    public let capture: CaptureName?
    public let modifiers: CaptureModifierSet

    public init(range: NSRange, capture: CaptureName?, modifiers: CaptureModifierSet = []) {
        self.range = range
        self.capture = capture
        self.modifiers = modifiers
    }
}

public protocol TextViewCoordinator: AnyObject {
    func prepareCoordinator(controller: TextViewController)
    func controllerDidAppear(controller: TextViewController)
    func controllerDidDisappear(controller: TextViewController)
    func textViewDidChangeText(controller: TextViewController)
    func textViewDidChangeSelection(controller: TextViewController, newPositions: [CursorPosition])
    func destroy()
}

public struct CursorPosition: Sendable, Codable, Equatable, Hashable {
    public struct Position: Sendable, Codable, Equatable, Hashable {
        public let line: Int
        public let column: Int

        public init(line: Int, column: Int) {
            self.line = line
            self.column = column
        }
    }

    public let range: NSRange
    public let start: Position
    public let end: Position?

    public init(line: Int, column: Int) {
        self.range = .notFound
        self.start = Position(line: line, column: column)
        self.end = nil
    }

    public init(start: Position, end: Position?) {
        self.range = .notFound
        self.start = start
        self.end = end
    }

    public init(range: NSRange) {
        self.range = range
        self.start = Position(line: -1, column: -1)
        self.end = nil
    }
}

public extension TextViewCoordinator {
    func controllerDidAppear(controller: TextViewController) { }
    func controllerDidDisappear(controller: TextViewController) { }
    func textViewDidChangeText(controller: TextViewController) { }
    func textViewDidChangeSelection(controller: TextViewController, newPositions: [CursorPosition]) { }
    func destroy() { }
}

public protocol HighlightProviding: AnyObject {
    @MainActor
    func setUp(textView: TextView, codeLanguage: CodeLanguage)

    @MainActor
    func willApplyEdit(textView: TextView, range: NSRange)

    @MainActor
    func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    )

    @MainActor
    func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    )
}

public extension HighlightProviding {
    func willApplyEdit(textView: TextView, range: NSRange) { }
}

public enum CaptureName: Int8, CaseIterable, Sendable {
    case comment, punctuation, keyword, `operator`, number, string, character
    case function, method, `class`, `struct`, `enum`, `protocol`, `extension`, type
    case variable, property, constant, parameter, label, attribute, namespace
    case bool, builtin, macro, module, regex, tag, heading, link

    public static func fromString(_ string: String?) -> CaptureName? {
        guard let string else { return nil }
        switch string {
        case "comment": return .comment
        case "punctuation": return .punctuation
        case "keyword": return .keyword
        case "operator": return .operator
        case "number": return .number
        case "string": return .string
        case "character": return .character
        case "function": return .function
        case "method": return .method
        case "class": return .class
        case "struct": return .struct
        case "enum": return .enum
        case "protocol": return .protocol
        case "extension": return .extension
        case "type": return .type
        case "variable": return .variable
        case "property": return .property
        case "constant": return .constant
        case "parameter": return .parameter
        case "label": return .label
        case "attribute": return .attribute
        case "namespace": return .namespace
        case "bool": return .bool
        case "builtin": return .builtin
        case "macro": return .macro
        case "module": return .module
        case "regex": return .regex
        case "tag": return .tag
        case "heading": return .heading
        case "link": return .link
        default: return nil
        }
    }
}

public enum CaptureModifier: Int8, CaseIterable, Sendable {
    case declaration
    case definition
    case readonly
    case `static`
    case deprecated
    case abstract
    case `async`
    case modification
    case documentation
    case defaultLibrary

    public var stringValue: String {
        switch self {
        case .declaration: return "declaration"
        case .definition: return "definition"
        case .readonly: return "readonly"
        case .static: return "static"
        case .deprecated: return "deprecated"
        case .abstract: return "abstract"
        case .async: return "async"
        case .modification: return "modification"
        case .documentation: return "documentation"
        case .defaultLibrary: return "defaultLibrary"
        }
    }

    public static func fromString(_ string: String) -> CaptureModifier? {
        switch string {
        case "declaration": return .declaration
        case "definition": return .definition
        case "readonly": return .readonly
        case "static": return .static
        case "deprecated": return .deprecated
        case "abstract": return .abstract
        case "async": return .async
        case "modification": return .modification
        case "documentation": return .documentation
        case "defaultLibrary": return .defaultLibrary
        default: return nil
        }
    }
}

public class CombineCoordinator: TextViewCoordinator {
    public var textUpdatePublisher: AnyPublisher<Void, Never> {
        updateSubject.eraseToAnyPublisher()
    }

    public var selectionUpdatePublisher: AnyPublisher<[CursorPosition], Never> {
        selectionSubject.eraseToAnyPublisher()
    }

    private let updateSubject: PassthroughSubject<Void, Never> = .init()
    private let selectionSubject: CurrentValueSubject<[CursorPosition], Never> = .init([])

    public init() { }

    public func prepareCoordinator(controller: TextViewController) { }

    public func textViewDidChangeText(controller: TextViewController) {
        updateSubject.send()
    }

    public func textViewDidChangeSelection(controller: TextViewController, newPositions: [CursorPosition]) {
        selectionSubject.send(newPositions)
    }

    public func destroy() {
        updateSubject.send(completion: .finished)
        selectionSubject.send(completion: .finished)
    }
}

public struct CaptureModifierSet: OptionSet, Equatable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let declaration = CaptureModifierSet(rawValue: 1 << 0)
    public static let definition = CaptureModifierSet(rawValue: 1 << 1)
    public static let readonly = CaptureModifierSet(rawValue: 1 << 2)
    public static let `static` = CaptureModifierSet(rawValue: 1 << 3)
    public static let deprecated = CaptureModifierSet(rawValue: 1 << 4)
    public static let abstract = CaptureModifierSet(rawValue: 1 << 5)
    public static let async = CaptureModifierSet(rawValue: 1 << 6)
    public static let modification = CaptureModifierSet(rawValue: 1 << 7)

    public static func fromString(_ string: String?) -> CaptureModifierSet? {
        guard let string else { return nil }
        switch string {
        case "declaration": return .declaration
        case "definition": return .definition
        case "readonly": return .readonly
        case "static": return .static
        case "deprecated": return .deprecated
        case "abstract": return .abstract
        case "async": return .async
        case "modification": return .modification
        default: return nil
        }
    }
}
