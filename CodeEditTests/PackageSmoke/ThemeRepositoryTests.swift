//
//  ThemeRepositoryTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-09.
//

import Foundation
import Testing
@testable import CodeEdit

@Suite
struct ThemeRepositoryTests {
    @Test
    func bundledDefaultThemeParsesAndCarriesBothVariants() {
        let theme = ThemeRepository.bundledDefaultTheme()

        #expect(theme.name == ThemeRepository.bundledDefaultThemeName)
        #expect(theme.light != nil)
        #expect(theme.dark != nil)
    }

    @Test
    func discoverBundledThemeURLsFindsTheShippedStandardTheme() {
        let urls = ThemeRepository.discoverBundledThemeURLs()

        #expect(urls.contains { $0.lastPathComponent == "standard.yaml" })
    }

    @Test
    func loadAllThemesIncludesTheBundledDefaultWhenTheUserDirectoryIsEmpty() {
        // Exercises UserDataDirectories's overrideRoot with a fresh temp root,
        // proving discovery creates the directory and returns no user themes,
        // while the bundled theme is still present.
        let tempRoot = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let themes = ThemeRepository.loadAllThemes(overrideRoot: tempRoot)

        #expect(themes.contains { $0.name == ThemeRepository.bundledDefaultThemeName })
        #expect(themes.count == 1)
    }

    @Test
    func userThemeWithANewNameCoexistsWithTheBundledTheme() throws {
        let tempRoot = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let themesDirectory = try UserDataDirectories.ensureDirectoryExists(for: .themes, overrideRoot: tempRoot)
        try Self.oneOffUserThemeYAML.write(
            to: themesDirectory.appending(path: "midnight.yaml"),
            atomically: true,
            encoding: .utf8
        )

        let themes = ThemeRepository.loadAllThemes(overrideRoot: tempRoot)

        #expect(themes.contains { $0.name == "midnight" })
        #expect(themes.contains { $0.name == ThemeRepository.bundledDefaultThemeName })
    }

    @Test
    func userThemeSharingTheBundledNameWinsOnCollision() throws {
        // "Theme collision identity" (Resolved decisions): collisions resolve on
        // the schema name field, not the file stem, and the user copy wins.
        let tempRoot = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let themesDirectory = try UserDataDirectories.ensureDirectoryExists(for: .themes, overrideRoot: tempRoot)
        try Self.userOverrideOfStandardYAML.write(
            to: themesDirectory.appending(path: "my_custom_filename.yaml"),
            atomically: true,
            encoding: .utf8
        )

        let themes = ThemeRepository.loadAllThemes(overrideRoot: tempRoot)
        let standardTheme = themes.first { $0.name == ThemeRepository.bundledDefaultThemeName }

        #expect(themes.count == 1)
        #expect(standardTheme?.light?.baseText == ThemeColor(hex: "#123456"))
    }

    @Test
    func malformedUserThemeIsSkippedAndTheBundledThemeStaysAvailable() throws {
        let tempRoot = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let themesDirectory = try UserDataDirectories.ensureDirectoryExists(for: .themes, overrideRoot: tempRoot)
        try "not: a, valid # theme\nkey without colon".write(
            to: themesDirectory.appending(path: "broken.yaml"),
            atomically: true,
            encoding: .utf8
        )

        let themes = ThemeRepository.loadAllThemes(overrideRoot: tempRoot)

        #expect(themes.count == 1)
        #expect(themes.first?.name == ThemeRepository.bundledDefaultThemeName)
    }

    @Test
    func resolvedThemeFallsBackToTheBundledDefaultWhenTheRequestedNameIsMissing() {
        let tempRoot = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let theme = ThemeRepository.resolvedTheme(named: "does_not_exist", overrideRoot: tempRoot)

        #expect(theme.name == ThemeRepository.bundledDefaultThemeName)
    }

    @Test
    func resolvedThemeCachesUntilInvalidated() throws {
        // Proves ThemeRepository.resolvedTheme(named:) caches its result: the
        // theme resolved once for a name keeps resolving to the same theme
        // even after the underlying user theme file is deleted from disk,
        // until invalidateCache() forces fresh discovery to see the deletion.
        let tempRoot = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let themesDirectory = try UserDataDirectories.ensureDirectoryExists(for: .themes, overrideRoot: tempRoot)
        let themeFile = themesDirectory.appending(path: "ephemeral.yaml")
        try Self.oneOffUserThemeYAML.write(to: themeFile, atomically: true, encoding: .utf8)

        let firstResolve = ThemeRepository.resolvedTheme(named: "midnight", overrideRoot: tempRoot)
        #expect(firstResolve.name == "midnight")

        try FileManager.default.removeItem(at: themeFile)

        let cachedResolve = ThemeRepository.resolvedTheme(named: "midnight", overrideRoot: tempRoot)
        #expect(cachedResolve.name == "midnight")

        ThemeRepository.invalidateCache()

        let freshResolve = ThemeRepository.resolvedTheme(named: "midnight", overrideRoot: tempRoot)
        #expect(freshResolve.name == ThemeRepository.bundledDefaultThemeName)
    }

    #if DEBUG
    @Test
    func registeredInMemoryThemeResolvesByNameThenFallsBackAfterClear() throws {
        // Backs the live-apply self-test: a distinctly-named in-memory
        // theme must resolve ahead of disk so a genuine theme-name change is
        // observable with only one bundled theme, and clearing it must restore
        // the disk/bundled fallback so the seam leaves no lingering state.
        defer { ThemeRepository.clearInMemoryThemes() }
        let base = ThemeRepository.bundledDefaultTheme()
        let inMemory = SyntaxTheme(
            version: base.version,
            name: "in-memory-self-test",
            light: base.light,
            dark: base.dark
        )
        let registered = try #require(inMemory)

        ThemeRepository.registerInMemoryTheme(registered)
        let resolved = ThemeRepository.resolvedTheme(named: "in-memory-self-test")
        #expect(resolved.name == "in-memory-self-test")

        ThemeRepository.clearInMemoryThemes()
        let afterClear = ThemeRepository.resolvedTheme(named: "in-memory-self-test")
        #expect(afterClear.name == ThemeRepository.bundledDefaultThemeName)
    }
    #endif

    @Test
    func resolvedThemeReturnsTheBundledDefaultWhenNoNameIsRequestedYet() {
        // Matches PlainSyntaxHighlighter's current call site: no Settings scene
        // exists yet, so the highlighter always requests nil.
        let theme = ThemeRepository.resolvedTheme(named: nil)

        #expect(theme.name == ThemeRepository.bundledDefaultThemeName)
    }

    private func makeTempRoot() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    private static let oneOffUserThemeYAML = """
    version: 1
    name: midnight
    variants:
      dark:
        base_text: "#FFFFFF"
        background: "#000000"
    """

    private static let userOverrideOfStandardYAML = """
    version: 1
    name: standard
    variants:
      light:
        base_text: "#123456"
        background: "#FFFFFF"
    """
}
