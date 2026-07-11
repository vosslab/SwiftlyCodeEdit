//
//  CodeFileDocumentBridge.swift
//  SwiftlyCodeEdit
//
//  The single sanctioned document-layer AppKit boundary. Everything AppKit
//  that presents the retained NSDocument (`CodeFileDocument`) inside the SwiftUI
//  App scene lives here: the application delegate that reproduces the launch path,
//  the NSDocumentController glue for New/Open/Save/Save As/Close, and the
//  NSWindowController + NSHostingController that host CodeFileView. See
//  docs/active_plans/decisions/document_architecture_decision.md (bridge mechanism,
//  architect decision 2026-07-09). No other file added by the shell migration may
//  import AppKit at the document layer; CodeFileDocument.swift delegates its window
//  construction into CodeFileWindowBridge below.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
#if DEBUG
import CodeEditTextView
#endif

// MARK: - Application delegate

/// Reproduces the launch path under the SwiftUI lifecycle. Installed on the SwiftUI
/// `App` via `NSApplicationDelegateAdaptor`, so the app-shell file stays pure SwiftUI
/// while every AppKit call for launch and document hosting stays in this bridge.
@MainActor
final class ShellAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // A non-bundled SwiftPM executable launches as an accessory by default;
        // promote it to a regular foreground app so document windows and the menu
        // bar behave normally, matching the previous AppKit shell.
        NSApp.setActivationPolicy(.regular)
        #if DEBUG
        // Runs before any document window is created (window creation is deferred
        // to a later runloop turn in finishLaunch below), so a forced appearance
        // applies to every window and the toolbar from first paint.
        ForcedAppearanceOverride.applyIfRequested()
        #endif
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Marks that the running shell is the SwiftUI App, not the retired AppKit
        // enum entry point. Smoke and launch diagnostics key off this line.
        debugRuntimeLog("SHELL=SwiftUI")
        #endif
        finishLaunch()
        ShellDocumentActions.scheduleKillAfterIfRequested()
    }

    private func finishLaunch() {
        NSApp.activate(ignoringOtherApps: true)
        #if DEBUG
        debugRuntimeLog("Plain editor launch path ready: file-backed editor, open/save commands registered")
        ShellDocumentActions.logRuntimeBundleState()
        #endif
        // Defer menu logging and the default-document open to the next runloop turn
        // so SwiftUI has finished installing NSApp.mainMenu before it is inspected.
        DispatchQueue.main.async {
            #if DEBUG
            ShellDocumentActions.logMenuState()
            #endif
            ShellDocumentActions.openDefaultSourceFileIfNeeded()
        }
    }
}

// MARK: - Document actions (NSDocumentController glue)

/// Plain-Swift entry points the SwiftUI `App` command buttons call. All
/// NSDocumentController, NSOpenPanel, and responder-chain AppKit lives here so the
/// app-shell file names only these helpers.
@MainActor
enum ShellDocumentActions {
    /// Routes File > New through the shared document controller, per the bridge
    /// decision (one NSDocumentController owns every document and file presenter).
    static func newDocument() {
        NSDocumentController.shared.newDocument(nil)
    }

    /// Routes File > Open through a standard open panel, then loads the chosen file.
    static func openDocumentWithPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            openDocument(at: url)
        }
    }

    /// Loads a file into a `CodeFileDocument`, registers it with the shared
    /// controller, and builds its window. Mirrors the previous shell's open path,
    /// including the "Loaded document:" runtime marker the smoke test gates on.
    static func openDocument(at url: URL) {
        do {
            let documentType = UTType(filenameExtension: url.pathExtension)?.identifier
                ?? UTType.sourceCode.identifier
            let document = try CodeFileDocument(for: url, withContentsOf: url, ofType: documentType)
            NSDocumentController.shared.addDocument(document)
            document.makeWindowControllers()
            NSApp.activate(ignoringOtherApps: true)
            #if DEBUG
            debugRuntimeLog("Loaded document: \(url.path)")
            #endif
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// Sends Save down the responder chain to the active NSDocument.
    static func saveActiveDocument() {
        NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
    }

    /// Sends Save As down the responder chain to the active NSDocument.
    static func saveActiveDocumentAs() {
        NSApp.sendAction(#selector(NSDocument.saveAs(_:)), to: nil, from: nil)
    }

    /// Closes the key document window through the responder chain.
    static func closeActiveDocument() {
        NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: NSApp.keyWindow, from: nil)
    }

    /// Opens the default source file on launch when no document is open yet. Honors
    /// the smoke-test source override so validation launches load a known file.
    static func openDefaultSourceFileIfNeeded() {
        guard NSDocumentController.shared.documents.isEmpty else { return }
        if let override = smokeSourceFileURL() {
            openDocument(at: override)
            return
        }

        let repoRoot = repoRootURL()
        let defaultFile = repoRoot.appendingPathComponent(
            "CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift"
        )
        guard FileManager.default.fileExists(atPath: defaultFile.path) else { return }
        openDocument(at: defaultFile)
    }

    private static func repoRootURL() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private static func smokeSourceFileURL() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let path = environment["CODEEDIT_DEBUG_SOURCE_FILE"] ?? environment["SOURCE_FILE"]
        guard let path, !path.isEmpty else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    /// Validation-only backstop: with --kill-after=N present, quit N seconds after
    /// launch so smoke runs (markers plus screenshot capture) finish before the
    /// process is torn down. Absent the flag this is a no-op, so ordinary user
    /// launches never auto-quit.
    static func scheduleKillAfterIfRequested() {
        guard let seconds = CodeEditMain.killAfterSeconds() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            NSApp.terminate(nil)
        }
    }

    #if DEBUG
    static func logRuntimeBundleState() {
        debugRuntimeLog("Bundle.main.bundleURL: \(Bundle.main.bundleURL.path)")

        if let infoDictionary = Bundle.main.infoDictionary,
           let documentTypes = infoDictionary["CFBundleDocumentTypes"] {
            debugRuntimeLog("Bundle.main.infoDictionary[CFBundleDocumentTypes]: \(documentTypes)")
        } else {
            debugRuntimeLog("Bundle.main.infoDictionary[CFBundleDocumentTypes]: <missing>")
        }

        debugRuntimeLog("NSDocumentController.documentClassNames: \(NSDocumentController.shared.documentClassNames)")

        if let swiftType = UTType(filenameExtension: "swift") {
            debugRuntimeLog("UTType(swift): \(swiftType.identifier)")
            debugRuntimeLog(
                "UTType(swift) conformsTo sourceCode=\(swiftType.conforms(to: .sourceCode)) "
                + "text=\(swiftType.conforms(to: .text))"
            )
        } else {
            debugRuntimeLog("UTType(swift): <missing>")
        }

        let infoPlistURL = Bundle.main.bundleURL.appendingPathComponent("Info.plist")
        debugRuntimeLog("Bundle Info.plist exists: \(FileManager.default.fileExists(atPath: infoPlistURL.path))")
    }

    static func logMenuState() {
        guard let mainMenu = NSApp.mainMenu else {
            debugRuntimeLog("Main menu unavailable")
            return
        }

        let titles = mainMenu.items.compactMap { item -> String? in
            guard let submenu = item.submenu else { return item.title }
            let subitems = submenu.items.map(\.title).joined(separator: ", ")
            return "\(item.title): [\(subitems)]"
        }
        debugRuntimeLog("Main menu items: \(titles.joined(separator: " | "))")
    }
    #endif
}

// MARK: - Window hosting

/// Builds and installs the AppKit window that hosts the SwiftUI editor for a
/// document. Called from CodeFileDocument.makeWindowControllers so the NSWindow,
/// NSWindowController, and NSHostingController construction stays confined to this
/// bridge file.
@MainActor
enum CodeFileWindowBridge {
    static func installWindowController(for document: CodeFileDocument) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        // Narrow, integrated single-row toolbar with labels beside each icon
        // (Kate-style layout, per user direction). `.expanded` renders a tall band with
        // labels below the icon row; `.unifiedCompact` shrinks the toolbar into the
        // traffic-light corner with icon-only items. `.unified` is the compact,
        // title-integrated row that matches the reference.
        window.toolbarStyle = .unified
        // Gives the status bar's custom tinted glass (CodeFileView,
        // PlainEditorStatusBar) something colorful to sample.
        // `.tint()` on a glass surface only modulates whatever already composites
        // behind it (docs/LIQUID_GLASS.md section 11); the plain window background
        // has nothing to modulate, so the tint is invisible without this. A gentle
        // blend keeps the window a "clean, simple editor" while still giving the
        // status bar real color to refract. Resolved once against the effective
        // appearance at window-creation time; it does not track a later live
        // Dark Mode toggle while the window stays open (a known, minor limitation
        // of a static NSWindow.backgroundColor, left as a follow-up if it proves
        // to matter in practice).
        window.backgroundColor = CodeFileWindowBridge.glassPopBackdropColor()
        // Host the SwiftUI editor tree in an NSHostingController set as the window's
        // content view controller, per the bridge decision. WindowCodeFileView picks
        // the text vs non-text editor. The hosting content view collapses the window
        // to its fitting size, so restore the intended editor size explicitly.
        #if DEBUG
        // Forces the hosted status bar's reduce-transparency fallback so an automated
        // capture can show the opaque fill (PlainEditorStatusBar in CodeFileView.swift)
        // without a System Settings toggle. SwiftUI's own \.accessibilityReduceTransparency
        // is a read-only environment value with no writable key path, so the override
        // travels through the app-local forcedReduceTransparencyForStatusBar key instead;
        // PlainEditorStatusBar falls back to the real \.accessibilityReduceTransparency
        // whenever this override is nil, using the same launch-argument parsing the
        // runtime marker already applies. Leaving the override nil (argument absent)
        // means the real system Reduce Transparency setting keeps winning, including
        // live changes while the window stays open.
        let forcedReduceTransparency = PlainEditorAppearanceMarker.overrideBool(
            forKey: PlainEditorAppearanceMarker.forceReduceTransparencyKey, in: UserDefaults.standard
        )
        let hostingController = NSHostingController(
            rootView: WindowCodeFileView(codeFile: document)
                .environment(\.forcedReduceTransparencyForStatusBar, forcedReduceTransparency)
        )
        #else
        let hostingController = NSHostingController(rootView: WindowCodeFileView(codeFile: document))
        #endif
        // Bridge the SwiftUI `.toolbar` declared on the hosted editor tree into this
        // AppKit-hosted window's NSToolbar. macOS 26 renders a standard toolbar as
        // grouped rounded-capsule Liquid Glass automatically, so the item definitions
        // stay in SwiftUI (CodeFileView) and this one line is the only AppKit the
        // native toolbar needs. `.title` keeps the window title bridged alongside it.
        hostingController.sceneBridgingOptions = [.toolbars, .title]
        window.contentViewController = hostingController
        window.setContentSize(NSSize(width: 960, height: 600))

        let windowController = NSWindowController(window: window)
        if let fileURL = document.fileURL {
            windowController.shouldCascadeWindows = false
            if ProcessInfo.processInfo.environment["CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST"] == "1" {
                UserDefaults.standard.removeObject(forKey: "NSWindow Frame \(fileURL.path)")
            }
            windowController.windowFrameAutosaveName = fileURL.path
        }
        document.addWindowController(windowController)
        // Observe this window becoming key and closing so the editor command router
        // always targets the focused window's editor and drops a closed window's
        // entry. Keying on the document identity matches CodeFileView's registration.
        EditorWindowKeyObserver.attach(to: window, key: ObjectIdentifier(document))
        windowController.showWindow(nil)

        if let fileURL = document.fileURL {
            window.title = fileURL.lastPathComponent
        }
        #if DEBUG
        debugRuntimeLog("Created editor window for \(document.fileURL?.path ?? "<unknown>")")
        // Confirm the SwiftUI `.toolbar` bridged into this window's NSToolbar via
        // sceneBridgingOptions above. Checked on a later runloop turn because SwiftUI
        // installs the bridged toolbar after the hosting view first lays out. A zero
        // or missing count is the signal to fall back to a hand-built NSToolbar.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak window] in
            let itemCount = window?.toolbar?.items.count ?? 0
            debugRuntimeLog("TOOLBAR_BRIDGED items=\(itemCount)")
        }
        #endif

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        // Fires on the first document window only; must run before highlighting
        // (the first highlight is async) so the marker reflects launch-to-paint.
        CodeEditMain.logLaunchToWindowIfNeeded()
        #if DEBUG
        // Fires on the first document window only, right after it is on screen, so
        // a screenshot capture can be labeled by the mode the app actually
        // rendered with rather than a guess.
        AppearanceMarker.logOnceIfNeeded()
        #endif

        if let fileURL = document.fileURL,
           UserDefaults.standard.object(forKey: "NSWindow Frame \(fileURL.path)") == nil {
            window.center()
        }
    }

    // Tuned separately per scheme: dark backdrops need a
    // stronger blend to read as color at all, light backdrops need a lighter
    // touch to stay subtle. `blended(withFraction:of:)` mixes toward
    // `.windowBackgroundColor`, so a higher fraction means less accent.
    private static func glassPopBackdropColor() -> NSColor {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let neutralFraction: CGFloat = isDark ? 0.93 : 0.96
        return NSColor.controlAccentColor.blended(withFraction: neutralFraction, of: .windowBackgroundColor)
            ?? .windowBackgroundColor
    }
}

// MARK: - Key-window observation

/// Bridges AppKit key-window and close notifications into the editor command router,
/// which stays free of AppKit shell symbols. One observer is created
/// per editor window, keyed on the hosting document's identity so it matches
/// CodeFileView's registration. It reports the window becoming key (so menu commands
/// target the focused editor) and closing (so the router drops the entry), then tears
/// its own notification observers down on close.
@MainActor
private final class EditorWindowKeyObserver {
    // Retains the live observers so their notification blocks stay registered for the
    // window's lifetime; the close handler removes the entry, releasing the observer.
    private static var observers: [ObjectIdentifier: EditorWindowKeyObserver] = [:]

    private let windowKey: ObjectIdentifier
    private var tokens: [NSObjectProtocol] = []

    /// Starts observing `window`, forwarding key and close events under `key`. If the
    /// window is already key when attached (the launch path activates before this
    /// runs), records it active immediately so the first menu command resolves.
    static func attach(to window: NSWindow, key: ObjectIdentifier) {
        let observer = EditorWindowKeyObserver(window: window, key: key)
        observers[key] = observer
        if window.isKeyWindow {
            EditorCommandRouter.shared.setActiveWindow(key)
        }
    }

    private init(window: NSWindow, key: ObjectIdentifier) {
        self.windowKey = key
        let center = NotificationCenter.default

        // Notifications post on the main queue, so the router (main-actor isolated) is
        // safe to touch from inside these blocks.
        let becameKeyToken = center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                EditorCommandRouter.shared.setActiveWindow(key)
            }
        }

        let willCloseToken = center.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                EditorCommandRouter.shared.unregister(for: key)
                EditorWindowKeyObserver.detach(key: key)
            }
        }

        tokens = [becameKeyToken, willCloseToken]
    }

    /// Removes the notification observers and drops the retained instance.
    private static func detach(key: ObjectIdentifier) {
        guard let observer = observers.removeValue(forKey: key) else { return }
        for token in observer.tokens {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

// MARK: - Forced appearance override (DEBUG only)

#if DEBUG
/// Forces NSApp's effective appearance from a launch argument, so an
/// automated screenshot run can capture light and dark without touching the
/// real System Settings appearance. NSApp.effectiveAppearance otherwise
/// always tracks the live system mode -- passing "-AppleInterfaceStyle
/// Light|Dark" alone does not change it, since that key only carries meaning
/// through the AppKit call below. Applied from
/// ShellAppDelegate.applicationWillFinishLaunching, before any document
/// window exists, so every window and its toolbar render in the forced mode
/// from first paint. Absent the argument this is a no-op: NSApp.appearance
/// stays nil and effectiveAppearance keeps following the real system mode.
@MainActor
enum ForcedAppearanceOverride {
    static func applyIfRequested() {
        // NSArgumentDomain only (not merged UserDefaults.standard reads): see
        // PlainEditorAppearanceMarker.overrideAppearanceMode for why the merged
        // search list would leak the real system Dark Mode state.
        let argumentDomain = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        guard let mode = PlainEditorAppearanceMarker.overrideAppearanceMode(in: argumentDomain) else {
            return
        }
        NSApp.appearance = NSAppearance(named: mode == "dark" ? .darkAqua : .aqua)
    }
}
#endif

// MARK: - Appearance/accessibility marker (DEBUG only)

#if DEBUG
/// Logs a single per-launch runtime marker naming the effective appearance
/// mode plus reduced-transparency and increased-contrast state, so a
/// screenshot capture can be labeled by the mode the app actually
/// rendered with. The live NSApp.effectiveAppearance and NSWorkspace
/// accessibility reads are AppKit, so they stay confined to this sanctioned
/// bridge file; the override-argument parsing and line formatting live
/// AppKit-free in PlainEditorAppearanceMarker.
@MainActor
enum AppearanceMarker {
    private static var didLog = false

    /// Logs the marker once per launch. Calls from a second or later window
    /// are no-ops.
    static func logOnceIfNeeded() {
        guard !didLog else { return }
        didLog = true

        let bestMatch = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        let mode = bestMatch == .darkAqua ? "dark" : "light"

        let defaults = UserDefaults.standard
        // Marker-only override: the native toolbar's glass reduce-transparency
        // behavior is OS-owned and inherited from the standard NSToolbar
        // component, so this flag is not (and cannot be) force-applied to it.
        let reduceTransparency = PlainEditorAppearanceMarker.effectiveFlag(
            override: PlainEditorAppearanceMarker.overrideBool(
                forKey: PlainEditorAppearanceMarker.forceReduceTransparencyKey, in: defaults
            ),
            systemValue: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        )
        let increaseContrast = PlainEditorAppearanceMarker.effectiveFlag(
            override: PlainEditorAppearanceMarker.overrideBool(
                forKey: PlainEditorAppearanceMarker.forceIncreaseContrastKey, in: defaults
            ),
            systemValue: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        )

        debugRuntimeLog(
            PlainEditorAppearanceMarker.markerLine(
                mode: mode, reduceTransparency: reduceTransparency, increaseContrast: increaseContrast
            )
        )
    }
}
#endif

// MARK: - Window self-capture (DEBUG only)

#if DEBUG
/// Renders the editor window's own view hierarchy to a PNG on request, without
/// the macOS screen-recording (TCC) grant that external screenshot helpers need.
/// The rendering path uses `NSView.cacheDisplay`, which draws the view's own
/// backing store, so a capture succeeds in environments where `screencapture`
/// is denied. AppKit window/view rendering is confined to this sanctioned bridge
/// file; the launch-argument reading and path validation live AppKit-free in
/// `PlainEditorWindowCapture`. Activated only when the launch argument
/// `-PlainEditor.captureWindowTo <absolute path>` is present.
@MainActor
enum WindowCaptureScheduler {
    // One capture per launch: the seam fires for the first editor window that
    // reaches a settled highlight and then disarms.
    private static var didSchedule = false

    /// Arms the capture for `textView`'s window when the launch argument requests
    /// it. A no-op (and zero overhead) when the argument is absent.
    static func scheduleIfRequested(textView: TextView) {
        guard !didSchedule else { return }
        guard let destination = PlainEditorWindowCapture.resolveCaptureDestination(
            argument: PlainEditorWindowCapture.requestedDestinationPath()
        ) else {
            return
        }
        didSchedule = true

        // Capture only after the first highlight pass has fully applied, so the
        // PNG shows colored, laid-out text rather than a blank/unpainted window.
        // onHighlightSettled runs its completion once that pass's attribute paint
        // and layoutLines have landed.
        PlainSyntaxHighlighter.onHighlightSettled(storage: textView.textStorage) {
            // A short deferral past the settle callback lets the window finish
            // presenting and the highlight paint flush to the backing store
            // before the synchronous cacheDisplay reads it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                capture(textView: textView, to: destination)
            }
        }
    }

    /// Renders the window's content view to a PNG and writes it atomically. Logs
    /// `WINDOW_CAPTURE_WRITTEN path=<path>` on success; any failure logs a
    /// `WINDOW_CAPTURE_FAILED` marker and leaves any existing file untouched.
    private static func capture(textView: TextView, to destination: URL) {
        guard let window = textView.window, let contentView = window.contentView else {
            debugRuntimeLog("WINDOW_CAPTURE_FAILED reason=no-window path=\(destination.path)")
            return
        }

        let bounds = contentView.bounds
        guard bounds.width > 0, bounds.height > 0,
              let imageRep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            debugRuntimeLog("WINDOW_CAPTURE_FAILED reason=no-rep path=\(destination.path)")
            return
        }
        // Draw the view's own backing store into the bitmap. This is own-view
        // rendering, which needs no screen-recording grant.
        contentView.cacheDisplay(in: bounds, to: imageRep)

        guard let pngData = imageRep.representation(using: .png, properties: [:]), !pngData.isEmpty else {
            debugRuntimeLog("WINDOW_CAPTURE_FAILED reason=no-png path=\(destination.path)")
            return
        }

        writeAtomically(pngData: pngData, to: destination)
    }

    /// Writes fully-rendered PNG bytes to a sibling temp file, then swaps that
    /// file into the destination, so a failed render never truncates or deletes
    /// an existing file at the destination.
    private static func writeAtomically(pngData: Data, to destination: URL) {
        let tempURL = destination.deletingLastPathComponent()
            .appendingPathComponent("_wp_g0_capture_\(ProcessInfo.processInfo.processIdentifier).png.tmp")
        do {
            try pngData.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: destination)
            }
            debugRuntimeLog("WINDOW_CAPTURE_WRITTEN path=\(destination.path)")
        } catch {
            // Drop the temp file on failure so no partial artifact lingers; the
            // destination is left exactly as it was before this attempt.
            try? FileManager.default.removeItem(at: tempURL)
            debugRuntimeLog("WINDOW_CAPTURE_FAILED reason=write-error path=\(destination.path)")
        }
    }
}
#endif
