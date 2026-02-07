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
