// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CodeEditSymbols",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CodeEditSymbols",
            targets: ["CodeEditSymbols"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing.git",
            from: "1.9.0"
        ),
    ],
    targets: [
        .target(
            name: "CodeEditSymbols",
            dependencies: []
        ),
        .testTarget(
            name: "CodeEditSymbolsTests",
            dependencies: [
                "CodeEditSymbols",
                "SnapshotTesting"
            ]
        ),
    ]
)
