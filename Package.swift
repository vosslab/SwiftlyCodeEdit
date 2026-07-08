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
            ],
            path: "CodeEdit",
            exclude: [
                "AppDelegate.swift",
                "CodeEdit.entitlements",
                "Info.plist",
                "Preview Content",
                "World.swift",
                "Features/ActivityViewer",
                "Features/CEWorkspace",
                "Features/CEWorkspaceSettings",
                "Features/CodeEditUI",
                "Features/Commands",
                "Features/Documents/Controllers",
                "Features/Documents/Indexer",
                "Features/Documents/WorkspaceDocument",
                "Features/Extensions",
                "Features/Feedback",
                "Features/InspectorArea",
                "Features/LSP",
                "Features/Editor/JumpBar",
                "Features/Editor/Models",
                "Features/Editor/TabBar",
                "Features/Editor/Views/EditorAreaFileView.swift",
                "Features/Editor/Views/EditorAreaView.swift",
                "Features/Editor/Views/EditorLayoutView.swift",
                "Features/Editor/Views/LoadingFileView.swift",
                "Features/NavigatorArea",
                "Features/Notifications",
                "Features/OpenQuickly",
                "Features/Search",
                "Features/Settings",
                "Features/SplitView",
                "Features/SourceControl",
                "Features/StatusBar",
                "Features/Tasks",
                "Features/TerminalEmulator",
                "Features/UtilityArea",
                "Features/InspectorArea/Models/InspectorTab.swift",
                "WorkspaceSheets.swift",
                "WorkspaceView.swift",
                "Features/WindowCommands",
                "Features/WindowCommands/ExtensionCommands.swift",
                "Features/WindowCommands/EditorCommands.swift",
                "Features/Extensions/ExtensionDiscovery.swift",
                "Features/Extensions/ExtensionInfo.swift",
                "Features/Extensions/ExtensionSceneView.swift",
                "Features/Extensions/ExtensionsManager.swift",
                "Features/Extensions/ExtensionActivatorView.swift",
                "Features/Welcome",
                "ShellIntegration",
                "Utils/Compatibility",
                "Utils/DependencyInjection",
                "Utils/Environment",
                "Utils/Extensions/Date",
                "Utils/Extensions/LanguageIdentifier",
                "Utils/Extensions/LocalProcess",
                "Utils/Extensions/SemanticToken",
                "Utils/Extensions/TextView",
                "Utils/Extensions/URL",
                "Utils/ShellClient",
                "Utils/withTimeout.swift"
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Features/Keybindings/default_keybindings.json"),
            ]
        ),
        .testTarget(
            name: "CodeEditTests",
            dependencies: [
                "CodeEdit",
            ],
            path: "CodeEditTests/PackageSmoke",
            sources: [
                "CodeFileDocumentLifecycleTests.swift"
            ]
        ),
    ]
)
