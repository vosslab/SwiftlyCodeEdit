//
//  InspectorTab.swift
//  CodeEdit
//
//  Created by Wouter Hennen on 02/06/2023.
//

import SwiftUI

enum InspectorTab: String, WorkspacePanelTab {
    case file
    case gitHistory
    case internalDevelopment

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .file:
            return "doc"
        case .gitHistory:
            return "clock"
        case .internalDevelopment:
            return "hammer"
        }
    }

    var title: String {
        switch self {
        case .file:
            return "File Inspector"
        case .gitHistory:
            return "History Inspector"
        case .internalDevelopment:
            return "Internal Development"
        }
    }

    var body: some View {
        switch self {
        case .file:
            FileInspectorView()
        case .gitHistory:
            HistoryInspectorView()
        case .internalDevelopment:
            InternalDevelopmentInspectorView()
        }
    }
}
