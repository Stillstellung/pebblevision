// IssueCreateViewModel.swift
// PebbleVision

import Foundation

@Observable
final class IssueCreateViewModel {
    var title = ""
    var description = ""
    var issueType: String = "task"
    var priority: Priority = .p2

    // Relationship selections
    var selectedParents: [String] = []
    var selectedDeps: [String] = []

    // Available issues for typeahead
    var availableIssues: [Issue] = []

    var isSubmitting = false
    var error: PBError?
    var createdIssueID: String?

    let client: PBClient
    let project: Project

    init(client: PBClient, project: Project) {
        self.client = client
        self.project = project
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func fetchAvailableIssues() async {
        do {
            availableIssues = try await client.listIssues(in: project, all: true)
        } catch {
            availableIssues = []
        }
    }

    func submit() async -> String? {
        guard isValid else { return nil }
        isSubmitting = true
        error = nil
        do {
            let newID = try await client.createIssue(
                in: project,
                title: title.trimmingCharacters(in: .whitespaces),
                type: issueType.isEmpty ? nil : issueType,
                priority: priority,
                description: description.isEmpty ? nil : description
            )
            createdIssueID = newID

            // Add parent-child relationships
            for parentID in selectedParents {
                try await client.addDependency(in: project, from: newID, to: parentID, type: "parent-child")
            }

            // Add blocking dependencies
            for depID in selectedDeps {
                try await client.addDependency(in: project, from: newID, to: depID)
            }

            isSubmitting = false
            return newID
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSubmitting = false
        return nil
    }

    func reset() {
        title = ""
        description = ""
        issueType = "task"
        priority = .p2
        selectedParents = []
        selectedDeps = []
        error = nil
        createdIssueID = nil
    }
}
