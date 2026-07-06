// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CodeEditSyntaxDefinitions",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "CodeEditSyntaxDefinitions",
            targets: ["CodeEditSyntaxDefinitions"]
        )
    ],
    targets: [
        .target(
            name: "CodeEditSyntaxDefinitions",
            resources: [
                .process("Resources/Kate"),
                .process("Resources/TextMate"),
                .process("Resources/Sublime"),
                .process("Resources/Themes")
            ]
        )
    ]
)
