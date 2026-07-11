//
//  SwiftlyCodeEditApp.swift
//  SwiftlyCodeEdit
//
//  The single SwiftUI `App` entry point for the editor. SwiftUI owns the
//  app shell: this scene, its `Settings` window, and its file `Commands`. The
//  retained AppKit document model (`CodeFileDocument`, an `NSDocument`) is hosted
//  through `NSDocumentController` under this plain `App` scene, per
//  docs/active_plans/decisions/document_architecture_decision.md. Every AppKit
//  symbol needed for that hosting lives in the single sanctioned document-layer
//  bridge file, `CodeFileDocumentBridge.swift`; this file stays pure SwiftUI and
//  only names the bridge's delegate type and calls its plain-Swift action helpers.
//

import SwiftUI

@main
struct SwiftlyCodeEditApp: App {
    // The delegate that reproduces the launch path (activation policy, runtime-log
    // markers, default-document open, and the --kill-after backstop) under the
    // SwiftUI lifecycle. Its type is defined in CodeFileDocumentBridge.swift so all
    // AppKit stays inside the sanctioned bridge file.
    @NSApplicationDelegateAdaptor(ShellAppDelegate.self)
    private var appDelegate

    init() {
        // Force the launch-start capture as early as possible in the SwiftUI
        // lifecycle. App.init runs before any scene appears, so this is the
        // earliest first-party code point under the SwiftUI shell; it fixes the
        // baseline for LAUNCH_TO_WINDOW_MS, which the window bridge reports once
        // the first document window is ordered front.
        _ = CodeEditMain.launchStartNanoseconds
    }

    var body: some Scene {
        // Document windows are AppKit NSWindows built by CodeFileDocument's
        // makeWindowControllers (delegated into the bridge), created through
        // NSDocumentController, not by a SwiftUI WindowGroup or DocumentGroup. The
        // App declares a Settings scene here and attaches the full parity menu
        // (File, Edit, Find, Format) as SwiftUI Commands from EditorCommands.
        // SettingsWindowView (CodeEdit/Features/Settings/) is the full
        // font/theme/editing preferences surface built entirely in SwiftUI.
        Settings {
            SettingsWindowView()
        }
        .commands {
            EditorCommands()
        }
    }
}
