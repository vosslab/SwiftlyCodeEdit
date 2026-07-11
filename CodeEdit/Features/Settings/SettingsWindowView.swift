//
//  SettingsWindowView.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-10.
//

import SwiftUI

/// The full Settings scene content, wired into `SwiftlyCodeEditApp`'s
/// `Settings` scene (Cmd+,). Built entirely from standard SwiftUI controls
/// (`TabView`, `Form`, `Picker`, `Stepper`) so the window matches the current
/// macOS design system automatically, per docs/SWIFT_STYLE.md. Replaces
/// the earlier placeholder `ShellSettingsView` stub.
struct SettingsWindowView: View {
    var body: some View {
        TabView {
            FontSettingsView()
                .tabItem {
                    Label("General", systemImage: "textformat")
                }

            ThemeSettingsView()
                .tabItem {
                    Label("Theme", systemImage: "paintpalette")
                }

            EditingSettingsView()
                .tabItem {
                    Label("Editing", systemImage: "text.alignleft")
                }
        }
    }
}
