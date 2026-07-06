// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeEditTextView",
    platforms: [.macOS(.v26)],
    products: [
        // A Fast, Efficient text view for code.
        .library(
            name: "CodeEditTextView",
            targets: ["CodeEditTextView"]
        ),
    ],
    dependencies: [
        // Useful data structures
        .package(
            url: "https://github.com/apple/swift-collections.git",
            .upToNextMajor(from: "1.0.0")
        ),
    ],
	targets: [
		// The main text view target.
        .target(
            name: "CodeEditTextView",
            dependencies: [
                "TextStory",
                .product(name: "Collections", package: "swift-collections"),
                "CodeEditTextViewObjC"
            ]
        ),

        .target(
            name: "TextStory",
            dependencies: []
        ),

        // ObjC addons
        .target(
            name: "CodeEditTextViewObjC",
            publicHeadersPath: "include"
        ),

        // Tests for the text view
        .testTarget(
			name: "CodeEditTextViewTests",
			dependencies: [
                "CodeEditTextView"
            ]
        ),
    ]
)
