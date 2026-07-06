//
//  MainCommands.swift
//  CodeEdit
//
//  Created by Wouter Hennen on 13/03/2023.
//

import SwiftUI

struct MainCommands: Commands {
    @Environment(\.openWindow)
    var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About CodeEdit") {
                openWindow(sceneID: .about)
            }

            Button("Check for updates...") {
                NotificationCenter.default.post(name: SoftwareUpdater.checkForUpdatesRequested, object: nil)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                openWindow(sceneID: .settings)
            }
            .keyboardShortcut(",")
        }
    }
}
