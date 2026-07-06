// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CodeEdit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(
            name: "CodeEdit",
            targets: ["CodeEdit"]
        ),
    ],
    dependencies: [
        .package(path: "Packages/AboutWindow"),
        .package(path: "Packages/CodeEditHighlighting"),
        .package(path: "Packages/CodeEditLanguages"),
        .package(path: "Packages/CodeEditTextView"),
        .package(path: "Packages/CodeEditSyntaxDefinitions"),
        .package(path: "Packages/CodeEditSymbols"),
        .package(path: "Packages/WelcomeWindow"),
        .package(url: "https://github.com/ChimeHQ/ConcurrencyPlus", from: "0.4.1"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", from: "0.8.2"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.2"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
        .package(url: "https://github.com/johnsundell/collectionconcurrencykit", from: "0.2.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "1.2.0"),
        .package(url: "https://github.com/thecoolwinter/SwiftTerm", branch: "codeedit"),
        .package(url: "https://github.com/Wouter01/LogStream", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "CodeEdit",
            dependencies: [
                .product(name: "AboutWindow", package: "AboutWindow"),
                .product(name: "CodeEditHighlighting", package: "CodeEditHighlighting"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "CodeEditSyntaxDefinitions", package: "CodeEditSyntaxDefinitions"),
                .product(name: "CodeEditSymbols", package: "CodeEditSymbols"),
                .product(name: "ConcurrencyPlus", package: "ConcurrencyPlus"),
                .product(name: "LanguageClient", package: "LanguageClient"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "WelcomeWindow", package: "WelcomeWindow"),
                .product(name: "AnyCodable", package: "AnyCodable"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "CollectionConcurrencyKit", package: "collectionconcurrencykit"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "SwiftUIIntrospect", package: "SwiftUI-Introspect"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "LogStream", package: "LogStream"),
            ],
            path: "CodeEdit",
            exclude: [
                "Features/Extensions",
                "Features/InspectorArea/Models/InspectorTab.swift",
                "Features/NavigatorArea/Models/NavigatorTab.swift",
                "Features/WindowCommands/ExtensionCommands.swift",
                "Features/WindowCommands/EditorCommands.swift",
                "Features/Extensions/ExtensionDiscovery.swift",
                "Features/Extensions/ExtensionInfo.swift",
                "Features/Extensions/ExtensionSceneView.swift",
                "Features/Extensions/ExtensionsManager.swift",
                "Features/Extensions/ExtensionActivatorView.swift"
            ],
            resources: [
                .process("Assets.xcassets"),
            ]
        ),
    ]
)
