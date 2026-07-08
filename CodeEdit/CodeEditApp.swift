import AppKit
import CodeEditTextView
import SwiftUI
import UniformTypeIdentifiers

@main
struct CodeEditApp: App {
    @NSApplicationDelegateAdaptor(PlainEditorAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            PlainEditorCommands(appDelegate: appDelegate)
        }
    }
}

@MainActor
final class PlainEditorAppDelegate: NSObject, NSApplicationDelegate {
    let actionRouter = PlainEditorActionRouter.shared

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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

    private func openDefaultSourceFileIfNeeded() {
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
        activeTextView.copy(activeTextView)
        return true
    }

    func paste() -> Bool {
        guard let activeTextView else { return false }
        activeTextView.paste(activeTextView)
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
