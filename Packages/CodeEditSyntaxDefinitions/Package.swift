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
    dependencies: [
        .package(path: "../CodeEditHighlighting")
    ],
    targets: [
        .target(
            name: "CodeEditSyntaxDefinitions",
            dependencies: [
                .product(name: "CodeEditHighlighting", package: "CodeEditHighlighting")
            ],
			path: "Sources/CodeEditSyntaxDefinitions",
			resources: [
				.process("Resources/Vendor/Kate")
			]
		),
        .testTarget(
            name: "CodeEditSyntaxDefinitionsTests",
            dependencies: ["CodeEditSyntaxDefinitions"]
        )
    ]
)
