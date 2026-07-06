//
//  NavigatorTab.swift
//  CodeEdit
//
//  Created by Wouter Hennen on 02/06/2023.
//

import SwiftUI

enum NavigatorTab: String, WorkspacePanelTab {
    case project
    case sourceControl
    case search

    var systemImage: String {
        switch self {
        case .project:
            return "folder"
        case .sourceControl:
            return "vault"
        case .search:
            return "magnifyingglass"
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .project:
            return "Project"
        case .sourceControl:
            return "Source Control"
        case .search:
            return "Search"
        }
    }

    var body: some View {
        switch self {
        case .project:
            ProjectNavigatorView()
        case .sourceControl:
            SourceControlNavigatorView()
        case .search:
            FindNavigatorView()
        }
    }
}
