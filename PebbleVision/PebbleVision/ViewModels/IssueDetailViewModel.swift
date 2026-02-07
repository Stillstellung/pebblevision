// IssueDetailViewModel.swift
// PebbleVision

import Foundation

@Observable
final class IssueDetailViewModel {
    var issue: Issue?
    var isLoading = false
    var error: PBError?
    var isSaving = false
    var availableIssues: [Issue] = []

    // MARK: - Worker Info
    var workerInfo: WorkerInfo?
    private let workerService = WorkerInfoService()

    // MARK: - Git Info
    var gitCommits: [GitCommit] = []
    var gitBranches: [String] = []
    var hasGitRemote = false
    private let gitInfoService = GitInfoService()

    private let client: PBClient
    private let project: Project

    init(client: PBClient, project: Project) {
        self.client = client
        self.project = project
    }

    func fetchAvailableIssues() async {
        do {
            availableIssues = try await client.listIssues(in: project, all: true)
        } catch {
            availableIssues = []
        }
    }

    // MARK: - Worker Info Fetching

    func fetchWorkerInfo(for issueID: String) async {
        workerInfo = await workerService.discoverWorker(for: issueID, in: project)
    }

    // MARK: - Git Info Fetching

    func fetchGitInfo(for issueID: String) async {
        async let commits = gitInfoService.findCommits(for: issueID, in: project)
        async let branches = gitInfoService.findBranches(for: issueID, in: project)
        async let remote = gitInfoService.hasRemote(in: project)
        gitCommits = await commits
        gitBranches = await branches
        hasGitRemote = await remote
    }

    /// Notify the issue list to refresh after a mutation.
    private func requestListRefresh() {
        NotificationCenter.default.post(name: .pbRefreshRequested, object: nil)
    }

    func fetchIssue(id: String) async {
        isLoading = true
        error = nil
        do {
            issue = try await client.showIssue(in: project, issueID: id)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isLoading = false
    }

    func updateStatus(_ status: IssueStatus) async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.updateIssue(in: project, issueID: issue.id, status: status)
            await fetchIssue(id: issue.id)
            requestListRefresh()
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    func updatePriority(_ priority: Priority) async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.updateIssue(in: project, issueID: issue.id, priority: priority)
            await fetchIssue(id: issue.id)
            requestListRefresh()
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    func updateType(_ type: String) async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.updateIssue(in: project, issueID: issue.id, type: type)
            await fetchIssue(id: issue.id)
            requestListRefresh()
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    func updateDescription(_ description: String) async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.updateIssue(in: project, issueID: issue.id, description: description)
            await fetchIssue(id: issue.id)
            requestListRefresh()
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    func updateTitle(_ title: String) async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.updateIssue(in: project, issueID: issue.id, title: title)
            await fetchIssue(id: issue.id)
            requestListRefresh()
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    func closeIssue() async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.closeIssue(in: project, issueID: issue.id)
            await fetchIssue(id: issue.id)
            requestListRefresh()
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    func reopenIssue() async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.reopenIssue(in: project, issueID: issue.id)
            await fetchIssue(id: issue.id)
            requestListRefresh()
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    func addComment(body: String) async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.addComment(in: project, issueID: issue.id, body: body)
            await fetchIssue(id: issue.id)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    func addDependency(to targetID: String, type: String? = nil) async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.addDependency(in: project, from: issue.id, to: targetID, type: type)
            await fetchIssue(id: issue.id)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    func removeDependency(from targetID: String) async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.removeDependency(in: project, from: issue.id, to: targetID)
            await fetchIssue(id: issue.id)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    // MARK: - Parent-Child Relationships

    /// Add a parent to the current issue (current issue becomes child of parentID).
    func addParent(_ parentID: String) async {
        guard let issue else { return }
        isSaving = true
        do {
            // pb dep add <child> <parent> --type parent-child
            try await client.addDependency(in: project, from: issue.id, to: parentID, type: "parent-child")
            await fetchIssue(id: issue.id)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    /// Remove a parent from the current issue.
    func removeParent(_ parentID: String) async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.removeDependency(in: project, from: issue.id, to: parentID, type: "parent-child")
            await fetchIssue(id: issue.id)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    /// Add a child to the current issue (childID becomes child of current issue).
    func addChild(_ childID: String) async {
        guard let issue else { return }
        isSaving = true
        do {
            // pb dep add <child> <parent> --type parent-child
            try await client.addDependency(in: project, from: childID, to: issue.id, type: "parent-child")
            await fetchIssue(id: issue.id)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }

    /// Remove a child from the current issue.
    func removeChild(_ childID: String) async {
        guard let issue else { return }
        isSaving = true
        do {
            try await client.removeDependency(in: project, from: childID, to: issue.id, type: "parent-child")
            await fetchIssue(id: issue.id)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isSaving = false
    }
}
