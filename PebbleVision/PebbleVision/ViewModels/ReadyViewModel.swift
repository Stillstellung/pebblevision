// ReadyViewModel.swift
// PebbleVision

import Foundation

@Observable
final class ReadyViewModel {
    var readyIssues: [Issue] = []
    var isLoading = false
    var error: PBError?

    private let client: PBClient
    private let project: Project

    init(client: PBClient, project: Project) {
        self.client = client
        self.project = project
    }

    /// Fetches unblocked issues using `pb ready --json`.
    func fetchReady(silent: Bool = false) async {
        if !silent { isLoading = true }
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
