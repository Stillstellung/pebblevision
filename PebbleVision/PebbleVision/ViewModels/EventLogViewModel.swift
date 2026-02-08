// EventLogViewModel.swift
// PebbleVision

import Foundation

@Observable
final class EventLogViewModel {
    var events: [Event] = []
    var isLoading = false
    var error: PBError?
    var limit: Int = 50
    var sinceDate: Date?
    var untilDate: Date?

    private let client: PBClient
    private let project: Project

    init(client: PBClient, project: Project) {
        self.client = client
        self.project = project
    }

    /// Fetches events using `pb log --json --no-pager --no-git`.
    func fetchEvents(silent: Bool = false) async {
        if !silent { isLoading = true }
        error = nil
        do {
            events = try await client.eventLog(
                in: project,
                limit: limit,
                since: sinceDate,
                until: untilDate,
                noGit: true
            )
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isLoading = false
    }
}
