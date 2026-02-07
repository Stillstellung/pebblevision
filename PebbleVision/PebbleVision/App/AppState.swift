// AppState.swift
// PebbleVision
//
// Global navigation and UI state shared across the app.

import Foundation
import SwiftUI

@Observable
final class AppState {
    /// Navigation sections in the sidebar.
    enum Section: String, CaseIterable, Identifiable {
        case issues = "Issues"
        case ready = "Ready"
        case depTree = "Dependencies"
        case eventLog = "Event Log"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .issues: "list.bullet"
            case .ready: "checkmark.circle"
            case .depTree: "arrow.triangle.branch"
            case .eventLog: "clock"
            }
        }
    }

    var selectedSection: Section = .issues
    var selectedIssueID: String?
    var showCreateSheet = false
    var lastRefresh: Date?
    var globalError: PBError?

    /// Posts a refresh notification that ViewModels can observe.
    func requestRefresh() {
        NotificationCenter.default.post(name: .pbRefreshRequested, object: nil)
        lastRefresh = Date()
    }
}

extension Notification.Name {
    static let pbRefreshRequested = Notification.Name("pbRefreshRequested")
}
