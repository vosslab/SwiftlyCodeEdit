//
//  UserDataDirectories.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-09.
//

import Foundation

/// Owns the on-disk path policy for SwiftlyCodeEdit's user data directory under
/// `~/Library/Application Support/SwiftlyCodeEdit/`.
///
/// Both user themes (`Themes/`) and user Kate syntax XML (`Syntax/`) live under this
/// one base directory, so this helper is the single place that defines the app
/// identifier, the subdirectory names, directory creation, and discovery logging.
/// Every accessor takes an `overrideRoot` parameter so tests can point the helper at
/// a temporary directory instead of the real Application Support location.
enum UserDataDirectories {
    /// Named subdirectories under the SwiftlyCodeEdit user data directory.
    enum Subdirectory: String {
        case themes = "Themes"
        case syntax = "Syntax"
    }

    /// The folder name SwiftlyCodeEdit owns under Application Support.
    static let appDirectoryName = "SwiftlyCodeEdit"

    /// The base SwiftlyCodeEdit user data directory.
    ///
    /// - Parameter overrideRoot: When non-nil, used as the Application Support root
    ///   instead of the real `~/Library/Application Support` directory. Tests pass a
    ///   temporary directory here.
    static func baseURL(overrideRoot: URL? = nil, fileManager: FileManager = .default) -> URL {
        // The real root is the user's Application Support directory; tests substitute
        // their own temp root here so no test ever touches the real location.
        let applicationSupportRoot = overrideRoot ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupportRoot.appending(path: appDirectoryName, directoryHint: .isDirectory)
    }

    /// The URL for a named subdirectory under the base directory.
    static func url(
        for subdirectory: Subdirectory,
        overrideRoot: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        baseURL(overrideRoot: overrideRoot, fileManager: fileManager)
            .appending(path: subdirectory.rawValue, directoryHint: .isDirectory)
    }

    /// Creates the named subdirectory if it does not already exist.
    ///
    /// Idempotent: calling this repeatedly for the same subdirectory is safe and
    /// always returns the same URL.
    @discardableResult
    static func ensureDirectoryExists(
        for subdirectory: Subdirectory,
        overrideRoot: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directoryURL = url(for: subdirectory, overrideRoot: overrideRoot, fileManager: fileManager)
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            return directoryURL
        }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    /// Creates the named subdirectory if needed, then returns the file URLs found
    /// directly inside it (non-recursive, hidden files skipped).
    ///
    /// Logs the discovered count through `debugRuntimeLog` so discovery is visible
    /// during manual smoke testing.
    static func discoverFiles(
        in subdirectory: Subdirectory,
        overrideRoot: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        let directoryURL = try ensureDirectoryExists(
            for: subdirectory,
            overrideRoot: overrideRoot,
            fileManager: fileManager
        )
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let fileURLs = contents.filter { candidateURL in
            let resourceValues = try? candidateURL.resourceValues(forKeys: [.isDirectoryKey])
            return resourceValues?.isDirectory != true
        }
        debugRuntimeLog(
            "UserDataDirectories: discovered \(fileURLs.count) file(s) in " +
            "\(subdirectory.rawValue) at \(directoryURL.path)"
        )
        return fileURLs
    }
}
