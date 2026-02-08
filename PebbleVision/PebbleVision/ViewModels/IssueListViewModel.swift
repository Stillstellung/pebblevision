// IssueListViewModel.swift
// PebbleVision

import Foundation

@Observable
final class IssueListViewModel {
    var issues: [Issue] = []
    var isLoading = false
    var error: PBError?

    // Filter state
    var statusFilter: Set<IssueStatus> = [.open, .inProgress]
    var typeFilter: String?
    var priorityFilter: Priority?
    var showAll = false
    var searchText = ""

    // Sort state
    var sortField: IssueSortField = .date
    var sortAscending = false

    private let client: PBClient
    private let project: Project

    init(client: PBClient, project: Project) {
        self.client = client
        self.project = project
    }

    var filteredIssues: [Issue] {
        guard !searchText.isEmpty else { return issues }
        let query = searchText.lowercased()
        return issues.filter { issue in
            issue.title.lowercased().contains(query) ||
            issue.id.lowercased().contains(query) ||
            issue.issueType.lowercased().contains(query) ||
            issue.description.lowercased().contains(query)
        }
    }

    var sortedIssues: [Issue] {
        filteredIssues.sorted { a, b in
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

    func fetchIssues() async {
        isLoading = true
        error = nil
        do {
            issues = try await client.listIssues(
                in: project,
                status: showAll ? nil : statusFilter,
                type: typeFilter,
                priority: priorityFilter,
                all: showAll
            )
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isLoading = false
    }

    func refreshAfterMutation() async {
        await fetchIssues()
    }
}
