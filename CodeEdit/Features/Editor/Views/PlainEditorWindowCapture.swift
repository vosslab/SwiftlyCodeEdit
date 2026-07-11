//
//  PlainEditorWindowCapture.swift
//  CodeEdit
//
//  DEBUG-only in-app window self-capture seam. Renders the editor
//  window's own view hierarchy to a PNG, so release-evidence and smoke
//  screenshots need no macOS screen-recording (TCC) grant. This file holds the
//  pure, AppKit-free half: reading the launch argument and validating the
//  destination path. The actual NSView rendering lives in the sanctioned
//  document-layer bridge (CodeFileDocumentBridge.swift), the only place AppKit
//  window/view symbols are permitted for this seam.
//

#if DEBUG
import Foundation

/// AppKit-free helpers for the window self-capture seam. Kept separate from the
/// rendering bridge so the launch-argument reading and path validation are
/// unit-testable without an AppKit window.
enum PlainEditorWindowCapture {
    /// Launch-argument key. Passing `-PlainEditor.captureWindowTo <absolute path>`
    /// lands in UserDefaults' volatile NSArgumentDomain (per-process, never
    /// persisted), so the seam activates for exactly one launch with no
    /// `defaults write` and no lingering state.
    static let captureArgumentKey = "PlainEditor.captureWindowTo"

    /// Returns the requested destination path from the launch argument, or nil
    /// when the flag is absent. Reads the NSArgumentDomain via UserDefaults.
    static func requestedDestinationPath() -> String? {
        UserDefaults.standard.string(forKey: captureArgumentKey)
    }

    /// Validates a requested capture path and returns a file URL to write to, or
    /// nil when the argument is missing, empty, or not an absolute path. An
    /// absolute path is required so the destination never depends on the app's
    /// current working directory.
    static func resolveCaptureDestination(argument: String?) -> URL? {
        guard let argument, !argument.isEmpty else {
            return nil
        }
        // Absolute paths only: a relative path would resolve against the app's
        // working directory, which is not a stable capture target.
        guard argument.hasPrefix("/") else {
            return nil
        }
        let destinationURL = URL(fileURLWithPath: argument)
        return destinationURL
    }
}
#endif
