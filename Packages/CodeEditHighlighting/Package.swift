// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CodeEditHighlighting",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "CodeEditHighlighting",
            targets: ["CodeEditHighlighting"]
        )
    ],
    targets: [
        .target(
            name: "CodeEditHighlighting"
        ),
        .testTarget(
            name: "CodeEditHighlightingTests",
            dependencies: ["CodeEditHighlighting"]
        )
    ]
)
