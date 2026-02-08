// ReadyViewModel.swift
// PebbleVision

import Foundation

@Observable
final class ReadyViewModel {
    var readyIssues: [Issue] = []
    var isLoading = false
    var error: PBError?

    // Sort state
    var sortField: IssueSortField = .date
    var sortAscending = false

    var sortedReadyIssues: [Issue] {
        readyIssues.sorted { a, b in
            let result: Bool
            switch sortField {
            case .date:
                result = (a.createdAt ?? .distantPast) < (b.createdAt ?? .distantPast)
            case .priority:
                result = a.priority < b.priority
            case .type:
                result = a.issueType.localizedCompare(b.issueType) == .orderedAscending
            case .status:
                result = a.status.sortOrder < b.status.sortOrder
            }
            return sortAscending ? result : !result
        }
    }

    private let client: PBClient
    private let project: Project

    init(client: PBClient, project: Project) {
        self.client = client
        self.project = project
    }

    /// Fetches unblocked issues using `pb ready --json`.
    func fetchReady() async {
        isLoading = true
        error = nil
        do {
            readyIssues = try await client.readyIssues(in: project)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isLoading = false
    }
}
