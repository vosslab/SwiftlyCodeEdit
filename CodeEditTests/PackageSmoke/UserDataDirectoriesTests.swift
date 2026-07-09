//
//  UserDataDirectoriesTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-09.
//

import Testing
import Foundation
@testable import CodeEdit

@Suite
struct UserDataDirectoriesTests {
    @Test
    func baseURLNestsAppDirectoryNameUnderOverrideRoot() {
        let tempRoot = makeTempRoot()
        let baseURL = UserDataDirectories.baseURL(overrideRoot: tempRoot)

        #expect(baseURL == tempRoot.appending(path: "SwiftlyCodeEdit", directoryHint: .isDirectory))
    }

    @Test
    func subdirectoryURLsNestUnderTheBaseDirectory() {
        let tempRoot = makeTempRoot()
        let themesURL = UserDataDirectories.url(for: .themes, overrideRoot: tempRoot)
        let syntaxURL = UserDataDirectories.url(for: .syntax, overrideRoot: tempRoot)

        #expect(themesURL.path.hasSuffix("SwiftlyCodeEdit/Themes"))
        #expect(syntaxURL.path.hasSuffix("SwiftlyCodeEdit/Syntax"))
    }

    @Test
    func ensureDirectoryExistsCreatesTheDirectory() throws {
        let tempRoot = makeTempRoot()
        let fileManager = FileManager.default

        let createdURL = try UserDataDirectories.ensureDirectoryExists(for: .themes, overrideRoot: tempRoot)

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: createdURL.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
    }

    @Test
    func ensureDirectoryExistsIsIdempotent() throws {
        let tempRoot = makeTempRoot()

        let firstCallURL = try UserDataDirectories.ensureDirectoryExists(for: .syntax, overrideRoot: tempRoot)
        let secondCallURL = try UserDataDirectories.ensureDirectoryExists(for: .syntax, overrideRoot: tempRoot)

        #expect(firstCallURL == secondCallURL)
    }

    @Test
    func discoverFilesCreatesTheDirectoryWhenMissingAndReturnsEmpty() throws {
        let tempRoot = makeTempRoot()

        let discoveredURLs = try UserDataDirectories.discoverFiles(in: .syntax, overrideRoot: tempRoot)

        #expect(discoveredURLs.isEmpty)
        let syntaxURL = UserDataDirectories.url(for: .syntax, overrideRoot: tempRoot)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: syntaxURL.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
    }

    @Test
    func discoverFilesReturnsFilesPlacedInTheDirectory() throws {
        let tempRoot = makeTempRoot()
        let themesURL = try UserDataDirectories.ensureDirectoryExists(for: .themes, overrideRoot: tempRoot)
        let firstThemeURL = themesURL.appending(path: "one.json")
        let secondThemeURL = themesURL.appending(path: "two.json")
        try Data("{}".utf8).write(to: firstThemeURL)
        try Data("{}".utf8).write(to: secondThemeURL)

        let discoveredURLs = try UserDataDirectories.discoverFiles(in: .themes, overrideRoot: tempRoot)

        #expect(discoveredURLs.count == 2)
    }

    @Test
    func discoverFilesSkipsNestedDirectories() throws {
        let tempRoot = makeTempRoot()
        let themesURL = try UserDataDirectories.ensureDirectoryExists(for: .themes, overrideRoot: tempRoot)
        let nestedDirectoryURL = themesURL.appending(path: "nested", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: nestedDirectoryURL, withIntermediateDirectories: true)
        let themeFileURL = themesURL.appending(path: "one.json")
        try Data("{}".utf8).write(to: themeFileURL)

        let discoveredURLs = try UserDataDirectories.discoverFiles(in: .themes, overrideRoot: tempRoot)

        #expect(discoveredURLs.count == 1)
        #expect(discoveredURLs.first?.lastPathComponent == themeFileURL.lastPathComponent)
    }
}

private func makeTempRoot() -> URL {
    FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
}
