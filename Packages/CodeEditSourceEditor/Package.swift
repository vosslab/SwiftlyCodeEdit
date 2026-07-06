// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeEditSourceEditor",
    defaultLocalization: "en",
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
                "Extensions/NSRange+/NSRange+TSRange.swift",
                "Extensions/NSRange+/NSRange+InputEdit.swift",
                "Extensions/Node+filterChildren.swift",
                "Extensions/Tree+prettyPrint.swift",
                "Extensions/TextView+/TextView+Point.swift",
                "Extensions/TextView+/TextView+createReadBlock.swift",
                "Filters/TagFilter.swift",
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
            ]
        ),
    ]
)
