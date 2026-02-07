// DependencyTreeViewModel.swift
// PebbleVision

import Foundation

@Observable
final class DependencyTreeViewModel {
    var rootNode: DepNode?
    var isLoading = false
    var error: PBError?
    var selectedIssueID: String = ""

    private let client: PBClient
    private let project: Project

    init(client: PBClient, project: Project) {
        self.client = client
        self.project = project
    }

    func fetchTree(for issueID: String) async {
        let trimmed = issueID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        error = nil
        do {
            rootNode = try await client.dependencyTree(in: project, issueID: trimmed)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isLoading = false
    }
}
