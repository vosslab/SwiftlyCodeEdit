//
//  InspectorAreaView.swift
//  CodeEdit
//
//  Created by Austin Condiff on 3/21/22.
//

import SwiftUI

struct InspectorAreaView: View {
    @EnvironmentObject private var workspace: WorkspaceDocument
    @EnvironmentObject private var editorManager: EditorManager
    @ObservedObject public var viewModel: InspectorAreaViewModel

    @AppSettings(\.general.inspectorTabBarPosition)
    var sidebarPosition: SettingsData.SidebarTabBarPosition

    @AppSettings(\.developerSettings.showInternalDevelopmentInspector)
    var showInternalDevelopmentInspector

    init(viewModel: InspectorAreaViewModel) {
        self.viewModel = viewModel
        updateTabs()
    }

    private func updateTabs() {
        var tabs: [InspectorTab] = [.file, .gitHistory]

        if showInternalDevelopmentInspector {
            tabs.append(.internalDevelopment)
        }

        viewModel.tabItems = tabs
    }

    var body: some View {
        WorkspacePanelView(
            viewModel: viewModel,
            selectedTab: $viewModel.selectedTab,
            tabItems: $viewModel.tabItems,
            sidebarPosition: sidebarPosition
        )
        .formStyle(.grouped)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("inspector")
        .onChange(of: showInternalDevelopmentInspector) { _, _ in
            updateTabs()
        }
    }
}
