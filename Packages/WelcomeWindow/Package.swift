// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "WelcomeWindow",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "WelcomeWindow",
            targets: ["WelcomeWindow"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "WelcomeWindow"
        ),
        .testTarget(name: "WelcomeWindowTests", dependencies: ["WelcomeWindow"])
    ]
)
