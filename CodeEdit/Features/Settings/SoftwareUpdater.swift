//
//  SoftwareUpdater.swift
//  CodeEdit
//
//  Created by Austin Condiff on 9/19/22.
//

import Foundation

@MainActor
final class SoftwareUpdater: ObservableObject {
    static let checkForUpdatesRequested = Notification.Name("SoftwareUpdater.checkForUpdatesRequested")

    @Published var automaticallyChecksForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    @Published var includePrereleaseVersions = true {
        didSet {
            UserDefaults.standard.setValue(includePrereleaseVersions, forKey: "includePrereleaseVersions")
        }
    }

    init() {
        includePrereleaseVersions = UserDefaults.standard.bool(forKey: "includePrereleaseVersions")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCheckForUpdatesRequested),
            name: Self.checkForUpdatesRequested,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleCheckForUpdatesRequested() {
        checkForUpdates()
    }

    func checkForUpdates() {
        lastUpdateCheckDate = Date()
    }
}
