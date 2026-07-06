// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeEditSourceEditor",
    platforms: [.macOS(.v26)],
    products: [
        // A source editor with useful features for code editing.
        .library(
            name: "CodeEditSourceEditor",
            targets: ["CodeEditSourceEditor"]
        )
    ],
    dependencies: [
        // A fast, efficient, text view for code.
        .package(path: "../CodeEditTextView"),
        // Shared highlight model for the editor surface.
        .package(path: "../CodeEditHighlighting"),
        // Declarative syntax definition resources.
        .package(path: "../CodeEditSyntaxDefinitions"),
        .package(path: "../CodeEditLanguages"),
        // CodeEditSymbols
        .package(path: "../CodeEditSymbols"),
        // SwiftLint
        .package(
            url: "https://github.com/lukepistrol/SwiftLintPlugin",
            from: "0.2.2"
        ),
        // Rules for indentation, pair completion, whitespace
        .package(
            url: "https://github.com/ChimeHQ/TextFormation",
            from: "0.8.2"
        ),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0")
    ],
    targets: [
        // A source editor with useful features for code editing.
        .target(
            name: "CodeEditSourceEditor",
            dependencies: [
                "CodeEditTextView",
                "CodeEditHighlighting",
                "CodeEditSyntaxDefinitions",
                "CodeEditLanguages",
                "TextFormation",
                "CodeEditSymbols"
            ],
            exclude: [
                "TreeSitter",
                "Highlighting/Highlighter.swift",
                "Highlighting/HighlightProviding",
                "Highlighting/HighlightRange.swift",
                "Highlighting/StyledRangeContainer",
                "Controller/TextViewController+Highlighter.swift",
                "Controller/TextViewController+TextFormation.swift",
                "Extensions/TreeSitterLanguage+TagFilter.swift",
                "Extensions/NSRange+/NSRange+TSRange.swift",
                "Extensions/NSRange+/NSRange+InputEdit.swift",
                "Extensions/Node+filterChildren.swift",
                "Extensions/Tree+prettyPrint.swift",
                "Extensions/TextView+/TextView+Point.swift",
                "Extensions/TextView+/TextView+createReadBlock.swift",
                "Filters/TagFilter.swift",
                "JumpToDefinition",
                "CodeSuggestion/Model/SuggestionViewModel.swift"
            ],
            plugins: [
                .plugin(name: "SwiftLint", package: "SwiftLintPlugin")
            ]
        ),

        // Tests for the source editor
        .testTarget(
            name: "CodeEditSourceEditorTests",
            dependencies: [
                "CodeEditSourceEditor",
                "CodeEditHighlighting",
                "CodeEditLanguages",
                .product(name: "CustomDump", package: "swift-custom-dump")
            ],
            plugins: [
                .plugin(name: "SwiftLint", package: "SwiftLintPlugin")
            ]
        ),
    ]
)
