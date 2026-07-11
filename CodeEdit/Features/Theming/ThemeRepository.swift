//
//  ThemeRepository.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-09.
//

import Foundation

/// Discovers, parses, and layers theme files: the bundled defaults shipped
/// inside the app, and user themes from Application Support
/// (`UserDataDirectories`). This is the only reader of theme files;
/// `PlainSyntaxHighlighter` resolves colors through this type instead of a
/// hardcoded palette.
///
/// Every function here is safe to call off the main actor: file I/O and
/// parsing do not touch actor-isolated state, and every returned value
/// (`SyntaxTheme`) is `Sendable`.
enum ThemeRepository {
    /// The schema `name` of the theme bundled inside the app. It is always
    /// present in the bundle, so it is the guaranteed fallback per
    /// docs/THEME_FORMAT.md rule 3.
    static let bundledDefaultThemeName = "standard"

    private static let recognizedThemeExtensions: Set<String> = ["yaml", "yml", "json"]

    // MARK: - Resolved-theme cache
    //
    // `resolvedTheme(named:)` is called from `PlainSyntaxHighlighter`'s
    // highlight pass, including the synchronous cached-span fast path, so it
    // must not perform bundle discovery, disk reads, and a full parse on
    // every call. `resolvedThemeCache` follows the same lock-guarded pattern
    // as `SyntaxDefinitionRepository` and `CompiledRegexCache`: an
    // `@unchecked Sendable` class holding an `NSLock`-guarded dictionary as
    // instance state, referenced through one immutable `static let`, so the
    // shared mutable cache stays a lock-protected instance rather than a
    // static var (which strict concurrency checking would reject).

    private static let resolvedThemeCache = ResolvedThemeCache()

    /// Clears every cached resolved theme. Call this after a user theme file
    /// on disk changes (for example a future Settings live-apply action);
    /// without it, `resolvedTheme(named:)` keeps returning the theme it
    /// resolved on the first call for that name.
    static func invalidateCache() {
        resolvedThemeCache.invalidate()
    }

    #if DEBUG
    // MARK: - In-memory themes (DEBUG live-apply self-test seam)
    //
    // The `SETTINGS_APPLIED key=theme` marker fires only when a highlight pass
    // resolves a theme whose `name` differs from the one last applied. The app
    // ships exactly one bundled theme (`standard`), and `resolveThemeFromDisk`
    // falls back to it for any unknown name, so no name change is observable
    // from a real theme switch without a second theme file -- and writing one
    // into the user's `~/Library/Application Support/SwiftlyCodeEdit/Themes/`
    // directory is out of bounds. This registry lets the live-apply self-test
    // (`PlainEditorSettingsApplySelfTest`) register a distinctly-named theme
    // purely in memory, so a genuine name change flows through the same
    // `resolvedTheme(named:)` path with zero disk or `UserDefaults`
    // persistence. Compiled only under DEBUG.
    private static let inMemoryThemes = InMemoryThemeRegistry()

    /// Registers a theme resolvable by its `name` from `resolvedTheme(named:)`
    /// for the rest of the process, taking precedence over disk discovery.
    /// Invalidates the resolved-theme cache so the next resolve sees it.
    static func registerInMemoryTheme(_ theme: SyntaxTheme) {
        inMemoryThemes.register(theme)
        invalidateCache()
    }

    /// Drops every in-memory theme and invalidates the resolved-theme cache so
    /// the next resolve for a formerly-registered name falls back to disk.
    static func clearInMemoryThemes() {
        inMemoryThemes.clear()
        invalidateCache()
    }
    #endif

    /// Every bundled theme file's URL. Bundled data files are `.copy`d into
    /// the app's resource bundle (see `Package.swift`), so `Bundle.module`
    /// resource lookup finds them directly by filename with no subdirectory
    /// prefix, matching `CodeEditSyntaxDefinitions`'s existing bundled-XML
    /// discovery pattern.
    static func discoverBundledThemeURLs(bundle: Bundle = .module) -> [URL] {
        recognizedThemeExtensions.flatMap { fileExtension in
            bundle.urls(forResourcesWithExtension: fileExtension, subdirectory: nil) ?? []
        }
    }

    /// Loads every theme reachable at this moment: bundled themes first,
    /// then user Application Support themes layered on top by schema
    /// `name` (user wins on a name collision), per docs/THEME_FORMAT.md's
    /// "Theme collision identity" decision. A theme file that fails to parse
    /// is skipped with a logged warning (rule 3); it never blocks discovery
    /// of the other files.
    static func loadAllThemes(overrideRoot: URL? = nil, bundle: Bundle = .module) -> [SyntaxTheme] {
        var themesByName: [String: SyntaxTheme] = [:]

        for url in discoverBundledThemeURLs(bundle: bundle) {
            guard let theme = loadTheme(at: url) else {
                debugRuntimeLog("ThemeRepository: skipped malformed bundled theme at \(url.path)")
                continue
            }
            themesByName[theme.name] = theme
        }

        let userFileURLs = (try? UserDataDirectories.discoverFiles(in: .themes, overrideRoot: overrideRoot)) ?? []
        for url in userFileURLs where recognizedThemeExtensions.contains(url.pathExtension.lowercased()) {
            guard let theme = loadTheme(at: url) else {
                debugRuntimeLog("ThemeRepository: skipped malformed user theme at \(url.lastPathComponent)")
                continue
            }
            themesByName[theme.name] = theme // user theme wins on name collision.
        }

        return Array(themesByName.values)
    }

    /// Reads and parses one theme file. Returns nil (rather than throwing)
    /// so every call site's fallback logic stays a simple `guard let`.
    static func loadTheme(at url: URL) -> SyntaxTheme? {
        guard let data = try? Data(contentsOf: url), let contents = String(data: data, encoding: .utf8) else {
            return nil
        }
        return try? ThemeParser.parse(contents: contents, fileExtension: url.pathExtension)
    }

    /// The bundled default theme, guaranteed present in normal operation. If
    /// the bundle resource is somehow unreadable or fails to parse -- a
    /// corrupted app bundle -- `emergencyFallbackTheme` keeps the app
    /// running rather than crashing, per docs/THEME_FORMAT.md rule 3's "the
    /// app keeps running" contract.
    static func bundledDefaultTheme(bundle: Bundle = .module) -> SyntaxTheme {
        for url in discoverBundledThemeURLs(bundle: bundle) {
            if let theme = loadTheme(at: url), theme.name == bundledDefaultThemeName {
                return theme
            }
        }
        debugRuntimeLog(
            "ThemeRepository: bundled default theme '\(bundledDefaultThemeName)' is missing or malformed; " +
            "using the emergency fallback theme"
        )
        return SyntaxTheme.emergencyFallbackTheme
    }

    /// Resolves the active theme by schema `name`, falling back to the
    /// bundled default with a logged warning when the name is nil, absent
    /// from every discovered theme, or every candidate failed to parse
    /// (rule 3). `name` is nil until the Settings scene ships a
    /// user-selectable theme name.
    ///
    /// The result is cached per `(requestedName, overrideRoot, bundle)` so
    /// repeated calls -- including the highlighter's per-keystroke fast path
    /// -- do not re-discover and re-parse theme files from disk. Call
    /// `invalidateCache()` to force the next call to rediscover.
    static func resolvedTheme(
        named requestedName: String?, overrideRoot: URL? = nil, bundle: Bundle = .module
    ) -> SyntaxTheme {
        let cacheKey = ResolvedThemeCacheKey(
            requestedName: requestedName,
            overrideRootPath: overrideRoot?.path,
            bundlePath: bundle.bundlePath
        )

        if let cached = resolvedThemeCache.theme(for: cacheKey) {
            return cached
        }

        let resolved = resolveThemeFromDisk(named: requestedName, overrideRoot: overrideRoot, bundle: bundle)
        resolvedThemeCache.store(resolved, for: cacheKey)
        return resolved
    }

    /// The uncached discovery + parse path `resolvedTheme(named:)` calls on
    /// a cache miss.
    private static func resolveThemeFromDisk(
        named requestedName: String?, overrideRoot: URL?, bundle: Bundle
    ) -> SyntaxTheme {
        guard let requestedName else {
            return bundledDefaultTheme(bundle: bundle)
        }
        #if DEBUG
        // A DEBUG in-memory theme (registered by the live-apply
        // self-test) resolves ahead of disk so a distinctly-named theme is
        // observable without a second bundled file or a user Themes-dir write.
        if let inMemory = inMemoryThemes.theme(named: requestedName) {
            return inMemory
        }
        #endif
        let themes = loadAllThemes(overrideRoot: overrideRoot, bundle: bundle)
        if let match = themes.first(where: { $0.name == requestedName }) {
            return match
        }
        debugRuntimeLog("ThemeRepository: requested theme '\(requestedName)' was not found; using the bundled default")
        return bundledDefaultTheme(bundle: bundle)
    }
}

/// Identifies one `ThemeRepository.resolvedTheme(named:)` call's inputs.
/// `overrideRoot` and `bundle` are test seams that can vary the discovered
/// file set, so both are folded into the key alongside the requested name.
private struct ResolvedThemeCacheKey: Hashable {
    let requestedName: String?
    let overrideRootPath: String?
    let bundlePath: String
}

/// Process-wide lock-guarded cache backing `ThemeRepository.resolvedTheme(named:)`,
/// mirroring `CompiledRegexCache`'s and `SyntaxDefinitionRepository`'s
/// lock-guarded lazy-loading pattern in `CodeEditSyntaxDefinitions`.
private final class ResolvedThemeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var themesByKey: [ResolvedThemeCacheKey: SyntaxTheme] = [:]

    func theme(for key: ResolvedThemeCacheKey) -> SyntaxTheme? {
        lock.lock()
        defer { lock.unlock() }
        return themesByKey[key]
    }

    func store(_ theme: SyntaxTheme, for key: ResolvedThemeCacheKey) {
        lock.lock()
        defer { lock.unlock() }
        themesByKey[key] = theme
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        themesByKey.removeAll()
    }
}

#if DEBUG
/// Process-wide lock-guarded registry of in-memory themes backing
/// `ThemeRepository.registerInMemoryTheme(_:)`. Mirrors `ResolvedThemeCache`'s
/// `@unchecked Sendable` NSLock pattern so a background resolve (the highlight
/// pass) can read it safely. DEBUG-only: it exists solely for the
/// live-apply self-test and never participates in a release build.
private final class InMemoryThemeRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var themesByName: [String: SyntaxTheme] = [:]

    func register(_ theme: SyntaxTheme) {
        lock.lock()
        defer { lock.unlock() }
        themesByName[theme.name] = theme
    }

    func theme(named name: String) -> SyntaxTheme? {
        lock.lock()
        defer { lock.unlock() }
        return themesByName[name]
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        themesByName.removeAll()
    }
}
#endif
