// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeEditLanguages",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "CodeEditLanguages",
            targets: ["CodeEditLanguages"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CodeEditLanguages",
            dependencies: ["CodeLanguagesContainer"],
            sources: [
                "CodeLanguage.swift",
                "CodeLanguage+Definitions.swift",
                "CodeLanguage+DetectLanguage.swift"
            ],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [.linkedLibrary("c++")]
        ),

        .target(
            name: "CodeLanguagesContainer",
            dependencies: [],
            path: "CodeLanguages-Container/CodeLanguages-Container",
            sources: ["dummy.c"],
            publicHeadersPath: "include"
        ),

        .testTarget(
            name: "CodeEditLanguagesTests",
            dependencies: ["CodeEditLanguages"],
            exclude: [
                "CodeEditLanguagesTests.swift"
            ]
        ),
    ]
)
