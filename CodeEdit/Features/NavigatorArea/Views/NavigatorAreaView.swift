//
//  NavigatorAreaView.swift
//  CodeEdit
//
//  Created by Lukas Pistrol on 17.03.22.
//

import SwiftUI

struct NavigatorAreaView: View {
    @ObservedObject private var workspace: WorkspaceDocument
    @ObservedObject public var viewModel: NavigatorAreaViewModel

    @AppSettings(\.general.navigatorTabBarPosition)
    var sidebarPosition: SettingsData.SidebarTabBarPosition

    init(workspace: WorkspaceDocument, viewModel: NavigatorAreaViewModel) {
        self.workspace = workspace
        self.viewModel = viewModel
        viewModel.tabItems = [.project, .sourceControl, .search]
    }

    var body: some View {
        WorkspacePanelView(
            viewModel: viewModel,
            selectedTab: $viewModel.selectedTab,
            tabItems: $viewModel.tabItems,
            sidebarPosition: sidebarPosition
        )
        .environmentObject(workspace)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("navigator")
    }
}
