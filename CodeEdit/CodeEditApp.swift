import AppKit
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
            PlainEditorCommands()
        }
    }
}

@MainActor
final class PlainEditorAppDelegate: NSObject, NSApplicationDelegate {
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
        let repoRoot = repoRootURL()
        let defaultFile = repoRoot.appendingPathComponent("CodeEdit/CodeEditApp.swift")
        guard FileManager.default.fileExists(atPath: defaultFile.path) else { return }
        openDocument(at: defaultFile)
    }

    private func repoRootURL() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
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

private struct PlainEditorCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    (NSApp.delegate as? PlainEditorAppDelegate)?.openDocument(at: url)
                }
            }
            .keyboardShortcut("o")

            Button("Open Example Source") {
                let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                let defaultFile = repoRoot.appendingPathComponent("CodeEdit/CodeEditApp.swift")
                (NSApp.delegate as? PlainEditorAppDelegate)?.openDocument(at: defaultFile)
            }
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                #if DEBUG
                debugRuntimeLog("Save command available")
                #endif
                NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("s")

            Button("Save As...") {
                NSApp.sendAction(#selector(NSDocument.saveAs(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("s", modifiers: [.shift, .command])

            Button("Close") {
                NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: NSApp.keyWindow, from: nil)
            }
            .keyboardShortcut("w")
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                NSApp.sendAction(#selector(UndoManager.undo), to: nil, from: nil)
            }
            .keyboardShortcut("z")

            Button("Redo") {
                NSApp.sendAction(#selector(UndoManager.redo), to: nil, from: nil)
            }
            .keyboardShortcut("z", modifiers: [.shift, .command])
        }

        CommandGroup(after: .undoRedo) {
            Button("Cut") {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("x")

            Button("Copy") {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("c")

            Button("Paste") {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("v")

            Button("Select All") {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
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
            EmptyView()
        }
    }
}
