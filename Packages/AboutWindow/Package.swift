// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AboutWindow",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "AboutWindow",
            targets: ["AboutWindow"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/lukepistrol/SwiftLintPlugin",
            from: "0.2.2"
        )
    ],
    targets: [
        .target(
            name: "AboutWindow",
            plugins: [
                .plugin(name: "SwiftLint", package: "SwiftLintPlugin")
            ]
        ),
        .testTarget(
            name: "AboutWindowTests",
            dependencies: ["AboutWindow"]
        ),
    ]
)
