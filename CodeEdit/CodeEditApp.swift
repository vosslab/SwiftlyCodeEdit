import AppKit
import CodeEditTextView
import SwiftUI
import UniformTypeIdentifiers

@main
@MainActor
enum CodeEditMain {
    // Captured on first access, which main() forces as its very first statement,
    // so LAUNCH_TO_WINDOW_MS measures from the start of main(), the earliest point
    // Swift application code runs, and so excludes dyld/framework load before main().
    static let launchStartNanoseconds = DispatchTime.now().uptimeNanoseconds
    private static let appDelegate = PlainEditorAppDelegate()
    private static var didLogLaunchToWindow = false

    static func main() {
        _ = launchStartNanoseconds
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        application.delegate = appDelegate
        application.mainMenu = PlainEditorMainMenu.make(appDelegate: appDelegate)
        // finishLaunching() posts the didFinishLaunching notification, which drives
        // applicationDidFinishLaunching(_:) -> finishPlainEditorLaunch() exactly once.
        // Calling finishPlainEditorLaunch() here as well would run the launch path twice.
        application.finishLaunching()
        application.run()
    }

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
    // ordered front and visible. Must not wait on highlighting completion (WP-Q0
    // made the first highlight async) so the number reflects true launch-to-paint.
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

@MainActor
final class PlainEditorAppDelegate: NSObject, NSApplicationDelegate {
    let actionRouter = PlainEditorActionRouter.shared

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        finishPlainEditorLaunch()
        scheduleKillAfterIfRequested()
    }

    // Validation-only backstop: with --kill-after=N present, quit N seconds after
    // the launch path finishes, giving smoke runs (markers plus screenshot capture)
    // time to complete before the process is torn down. Absent the flag, this is a
    // no-op, so ordinary user launches never auto-quit.
    func scheduleKillAfterIfRequested() {
        guard let seconds = CodeEditMain.killAfterSeconds() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            NSApp.terminate(nil)
        }
    }

    func finishPlainEditorLaunch() {
        NSApp.activate(ignoringOtherApps: true)
        #if DEBUG
        debugRuntimeLog("Plain editor launch path ready: file-backed editor, open/save commands registered")
        logRuntimeBundleState()
        logMenuState()
        #endif
        DispatchQueue.main.async {
            self.openDefaultSourceFileIfNeeded()
        }
    }

    func openDefaultSourceFileIfNeeded() {
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

    private func repoRootURL() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func smokeSourceFileURL() -> URL? {
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

    #if DEBUG
    private func logRuntimeBundleState() {
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
            debugRuntimeLog("UTType(swift) conformsTo sourceCode=\(swiftType.conforms(to: .sourceCode)) text=\(swiftType.conforms(to: .text))")
        } else {
            debugRuntimeLog("UTType(swift): <missing>")
        }

        let infoPlistURL = Bundle.main.bundleURL.appendingPathComponent("Info.plist")
        debugRuntimeLog("Bundle Info.plist exists: \(FileManager.default.fileExists(atPath: infoPlistURL.path))")
    }
    #endif

    func openDocument(at url: URL) {
        do {
            let documentType = UTType(filenameExtension: url.pathExtension)?.identifier ?? UTType.sourceCode.identifier
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

    func saveActiveDocument() {
        NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
    }

    func saveActiveDocumentAs() {
        NSApp.sendAction(#selector(NSDocument.saveAs(_:)), to: nil, from: nil)
    }

    @objc func newDocumentMenuItem(_ sender: Any?) {
        NSDocumentController.shared.newDocument(sender)
    }

    @objc func openDocumentMenuItem(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.openDocument(at: url)
        }
    }

    @objc func openExampleSourceMenuItem(_ sender: Any?) {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let defaultFile = repoRoot.appendingPathComponent(
            "CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift"
        )
        openDocument(at: defaultFile)
    }

    @objc func saveMenuItem(_ sender: Any?) {
        saveActiveDocument()
    }

    @objc func saveAsMenuItem(_ sender: Any?) {
        saveActiveDocumentAs()
    }

    @objc func closeMenuItem(_ sender: Any?) {
        NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: NSApp.keyWindow, from: sender)
    }

    @objc func undoMenuItem(_ sender: Any?) {
        undo()
    }

    @objc func redoMenuItem(_ sender: Any?) {
        redo()
    }

    @objc func cutMenuItem(_ sender: Any?) {
        cut()
    }

    @objc func copyMenuItem(_ sender: Any?) {
        _ = actionRouter.copy()
    }

    @objc func pasteMenuItem(_ sender: Any?) {
        paste()
    }

    @objc func selectAllMenuItem(_ sender: Any?) {
        selectAll()
    }

    @objc func cleanTextMenuItem(_ sender: Any?) {
        cleanText()
    }

    func undo() {
        _ = actionRouter.undo()
    }

    func redo() {
        _ = actionRouter.redo()
    }

    func cut() {
        _ = actionRouter.cut()
    }

    func copy() {
        _ = actionRouter.copy()
    }

    func paste() {
        _ = actionRouter.paste()
    }

    func selectAll() {
        _ = actionRouter.selectAll()
    }

    func cleanText() {
        _ = actionRouter.cleanText()
    }

    #if DEBUG
    private func logMenuState() {
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

@MainActor
final class PlainEditorActionRouter: ObservableObject {
    static let shared = PlainEditorActionRouter()

    @Published var canSave = false
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var canCleanText = false

    private weak var activeTextView: TextView?

    func register(textView: TextView) {
        activeTextView = textView
    }

    func undo() -> Bool {
        guard let undoManager = activeTextView?.undoManager, undoManager.canUndo else { return false }
        undoManager.undo()
        return true
    }

    func redo() -> Bool {
        guard let undoManager = activeTextView?.undoManager, undoManager.canRedo else { return false }
        undoManager.redo()
        return true
    }

    func cut() -> Bool {
        guard let activeTextView else { return false }
        activeTextView.cut(activeTextView)
        return true
    }

    func copy() -> Bool {
        guard let activeTextView else { return false }
        let range = activeTextView.selectedRange()
        guard range.location != NSNotFound, range.length > 0 else { return false }
        let selectedText = (activeTextView.string as NSString).substring(with: range)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText, forType: .string)
        return true
    }

    func paste() -> Bool {
        // Always read the live system pasteboard so text copied in any app pastes
        // correctly. A private copy buffer would override newer external content.
        guard let activeTextView,
              let pasteText = NSPasteboard.general.string(forType: .string) else {
            return false
        }
        let range = activeTextView.selectedRange()
        let replacementRange = range.location == NSNotFound ? NSRange(location: activeTextView.string.utf16.count, length: 0) : range
        activeTextView.replaceCharacters(in: replacementRange, with: pasteText)
        return true
    }

    func selectAll() -> Bool {
        guard let activeTextView else { return false }
        activeTextView.selectAll(nil)
        return true
    }

    func cleanText() -> Bool {
        guard let activeTextView, activeTextView.isEditable else { return false }
        let original = activeTextView.string
        let cleaned = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: original)
        guard cleaned != original else { return false }
        activeTextView.replaceCharacters(
            in: NSRange(location: 0, length: (original as NSString).length),
            with: cleaned
        )
        return true
    }
}

@MainActor
private enum PlainEditorMainMenu {
    static func make(appDelegate: PlainEditorAppDelegate) -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenu())
        mainMenu.addItem(fileMenu(appDelegate: appDelegate))
        mainMenu.addItem(editMenu(appDelegate: appDelegate))
        mainMenu.addItem(findMenu())
        return mainMenu
    }

    private static func appMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "SwiftlyCodeEdit")
        menu.addItem(withTitle: "Quit SwiftlyCodeEdit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = menu
        return item
    }

    private static func fileMenu(appDelegate: PlainEditorAppDelegate) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "File")
        menu.addItem(menuItem("New", "n", #selector(PlainEditorAppDelegate.newDocumentMenuItem(_:)), appDelegate))
        menu.addItem(menuItem("Open...", "o", #selector(PlainEditorAppDelegate.openDocumentMenuItem(_:)), appDelegate))
        menu.addItem(menuItem(
            "Open Example Source",
            "",
            #selector(PlainEditorAppDelegate.openExampleSourceMenuItem(_:)),
            appDelegate
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem("Save", "s", #selector(PlainEditorAppDelegate.saveMenuItem(_:)), appDelegate))
        let saveAs = menuItem("Save As...", "s", #selector(PlainEditorAppDelegate.saveAsMenuItem(_:)), appDelegate)
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(saveAs)
        menu.addItem(menuItem("Close", "w", #selector(PlainEditorAppDelegate.closeMenuItem(_:)), appDelegate))
        item.submenu = menu
        return item
    }

    private static func editMenu(appDelegate: PlainEditorAppDelegate) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")
        menu.addItem(menuItem("Undo", "z", #selector(PlainEditorAppDelegate.undoMenuItem(_:)), appDelegate))
        let redo = menuItem("Redo", "z", #selector(PlainEditorAppDelegate.redoMenuItem(_:)), appDelegate)
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem("Cut", "x", #selector(PlainEditorAppDelegate.cutMenuItem(_:)), appDelegate))
        menu.addItem(menuItem("Copy", "c", #selector(PlainEditorAppDelegate.copyMenuItem(_:)), appDelegate))
        menu.addItem(menuItem("Paste", "v", #selector(PlainEditorAppDelegate.pasteMenuItem(_:)), appDelegate))
        menu.addItem(menuItem("Select All", "a", #selector(PlainEditorAppDelegate.selectAllMenuItem(_:)), appDelegate))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem("Clean Text", "", #selector(PlainEditorAppDelegate.cleanTextMenuItem(_:)), appDelegate))
        item.submenu = menu
        return item
    }

    private static func findMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Find")
        menu.addItem(withTitle: "Find...", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        let replace = NSMenuItem(
            title: "Find and Replace...",
            action: #selector(NSTextView.performFindPanelAction(_:)),
            keyEquivalent: "f"
        )
        replace.keyEquivalentModifierMask = [.command, .option]
        replace.tag = 12
        menu.addItem(replace)
        item.submenu = menu
        return item
    }

    private static func menuItem(
        _ title: String,
        _ keyEquivalent: String,
        _ action: Selector,
        _ target: AnyObject
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        return item
    }
}

private struct PlainEditorCommands: Commands {
    let appDelegate: PlainEditorAppDelegate

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") {
                NSDocumentController.shared.newDocument(nil)
            }
            .keyboardShortcut("n")

            Button("Open...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    appDelegate.openDocument(at: url)
                }
            }
            .keyboardShortcut("o")

            Button("Open Example Source") {
                let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                let defaultFile = repoRoot.appendingPathComponent(
                    "CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift"
                )
                appDelegate.openDocument(at: defaultFile)
            }
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                #if DEBUG
                debugRuntimeLog("Save command available")
                #endif
                appDelegate.saveActiveDocument()
            }
            .keyboardShortcut("s")

            Button("Save As...") {
                appDelegate.saveActiveDocumentAs()
            }
            .keyboardShortcut("s", modifiers: [.shift, .command])

            Button("Close") {
                NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: NSApp.keyWindow, from: nil)
            }
            .keyboardShortcut("w")
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                appDelegate.undo()
            }
            .keyboardShortcut("z")

            Button("Redo") {
                appDelegate.redo()
            }
            .keyboardShortcut("z", modifiers: [.shift, .command])
        }

        CommandGroup(after: .undoRedo) {
            Button("Cut") {
                appDelegate.cut()
            }
            .keyboardShortcut("x")

            Button("Copy") {
                appDelegate.copy()
            }
            .keyboardShortcut("c")

            Button("Paste") {
                appDelegate.paste()
            }
            .keyboardShortcut("v")

            Button("Select All") {
                appDelegate.selectAll()
            }
            .keyboardShortcut("a")
        }

        CommandMenu("Find") {
            Button("Find...") {
                NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("f")

            Button("Find and Replace...") {
                let item = NSMenuItem()
                item.tag = 12
                NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: item)
            }
            .keyboardShortcut("f", modifiers: [.option, .command])
        }

        CommandGroup(after: .saveItem) {
            Button("Clean Text") {
                appDelegate.cleanText()
            }
        }
    }
}

extension TextView {
    @objc func cleanText(_ sender: Any?) {
        guard isEditable else { return }
        let cleaned = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: string)
        guard cleaned != string else { return }
        replaceCharacters(
            in: NSRange(location: 0, length: string.utf16.count),
            with: cleaned
        )
    }
}
