// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CodeEditKit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "CodeEditKit",
            type: .dynamic,
            targets: ["CodeEditKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/ConcurrencyPlus", from: "0.4.1"),
        .package(
            url: "https://github.com/Flight-School/AnyCodable",
            from: "0.6.0"
        )
    ],
    targets: [
        .target(
            name: "CodeEditKit",
            dependencies: ["AnyCodable", "ConcurrencyPlus"]
        ),
        .testTarget(
            name: "CodeEditKitTests",
            dependencies: ["CodeEditKit"])
    ]
)
