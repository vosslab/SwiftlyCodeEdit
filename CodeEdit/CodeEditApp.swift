import Foundation

// The @main entry point moved to CodeEdit/App/SwiftlyCodeEditApp.swift: the
// SwiftUI App is the single entry. The hand-built AppKit shell that used
// to live in this file was deleted (PlainEditorAppDelegate, PlainEditorMainMenu, and
// PlainEditorActionRouter); this enum now holds only the launch-metrics members the
// live shell and its document bridge still call: launchStartNanoseconds and
// logLaunchToWindowIfNeeded report LAUNCH_TO_WINDOW_MS, and killAfterSeconds parses
// the --kill-after flag for the shell's smoke-run backstop.
@MainActor
enum CodeEditMain {
    // Captured on first access, so LAUNCH_TO_WINDOW_MS measures from the earliest
    // point Swift application code runs, excluding dyld/framework load before that.
    static let launchStartNanoseconds = DispatchTime.now().uptimeNanoseconds
    private static var didLogLaunchToWindow = false

    // Parses --kill-after=N from the launch arguments. Returns nil when the flag
    // is absent so normal user launches never auto-quit.
    static func killAfterSeconds() -> Double? {
        let flagPrefix = "--kill-after="
        for argument in CommandLine.arguments where argument.hasPrefix(flagPrefix) {
            let secondsText = String(argument.dropFirst(flagPrefix.count))
            return Double(secondsText)
        }
        return nil
    }

    // Logs LAUNCH_TO_WINDOW_MS exactly once, the first time a document window is
    // ordered front and visible. Must not wait on highlighting completion (the
    // first highlight is async) so the number reflects true launch-to-paint.
    static func logLaunchToWindowIfNeeded() {
        guard !didLogLaunchToWindow else { return }
        didLogLaunchToWindow = true
        let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - launchStartNanoseconds
        let elapsedMilliseconds = elapsedNanoseconds / 1_000_000
        #if DEBUG
        debugRuntimeLog("LAUNCH_TO_WINDOW_MS=\(elapsedMilliseconds)")
        #endif
    }
}
