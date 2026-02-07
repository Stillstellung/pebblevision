import Foundation
import Observation

/// Scope for batch prefix rename operations.
enum RenamePrefixScope: Sendable {
    case open   // --open: only open issues
    case full   // --full: all issues
}

/// High-level async API wrapping every `pb` command.
/// Each method builds an argument array, calls ProcessRunner, then routes
/// output through the appropriate parser.
@Observable
final class PBClient: @unchecked Sendable {
    private let runner = ProcessRunner()
    private let textParser = PBOutputParser()
    private let jsonParser = PBJSONParser()

    /// User-configurable path to pb binary. Defaults to "pb" (found via PATH).
    var pbPath: String = "pb"

    // MARK: - Project Setup

    func initProject(at path: String, prefix: String? = nil) async throws {
        var args = ["init"]
        if let prefix {
            args += ["--prefix", prefix]
        }
        let output = try await runner.run(executable: pbPath, arguments: args, workingDirectory: path)
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
    }

    func importBeads(at path: String, from sourcePath: String, backup: Bool = false) async throws {
        var args = ["import", "beads", "--from", sourcePath]
        if backup {
            args.append("--backup")
        }
        let output = try await runner.run(executable: pbPath, arguments: args, workingDirectory: path)
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
    }

    // MARK: - Issue CRUD

    /// Create a new issue. Returns the new issue ID string.
    func createIssue(
        in project: Project,
        title: String,
        type: String? = nil,
        priority: Priority? = nil,
        description: String? = nil
    ) async throws -> String {
        var args = ["create", "--title", title]
        if let type {
            args += ["--type", type]
        }
        if let priority {
            args += ["--priority", priority.label]
        }
        if let description {
            args += ["--description", description]
        }
        let output = try await runner.run(
            executable: pbPath, arguments: args, workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
        return textParser.parseCreateOutput(output.stdout)
    }

    /// List issues with optional filtering.
    func listIssues(
        in project: Project,
        status: Set<IssueStatus>? = nil,
        type: String? = nil,
        priority: Priority? = nil,
        stale: Bool = false,
        staleDays: Int? = nil,
        all: Bool = false
    ) async throws -> [Issue] {
        var args = ["list", "--json"]
        if let status {
            args += ["--status", status.map(\.rawValue).joined(separator: ",")]
        }
        if let type {
            args += ["--type", type]
        }
        if let priority {
            args += ["--priority", priority.label]
        }
        if stale {
            args.append("--stale")
        }
        if let staleDays {
            args += ["--stale-days", "\(staleDays)"]
        }
        if all {
            args.append("--all")
        }
        let output = try await runner.run(
            executable: pbPath, arguments: args, workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
        return try jsonParser.parseIssueList(output.stdout)
    }

    /// Show full detail for a single issue, including hierarchy and comments.
    func showIssue(in project: Project, issueID: String) async throws -> Issue {
        let output = try await runner.run(
            executable: pbPath,
            arguments: ["show", "--json", issueID],
            workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            if output.stderr.lowercased().contains("not found") {
                throw PBError.issueNotFound(id: issueID)
            }
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
        return try jsonParser.parseIssueDetail(output.stdout)
    }

    /// Update an existing issue's properties.
    func updateIssue(
        in project: Project,
        issueID: String,
        status: IssueStatus? = nil,
        title: String? = nil,
        type: String? = nil,
        priority: Priority? = nil,
        description: String? = nil,
        parent: String? = nil
    ) async throws {
        var args = ["update", issueID]
        if let status {
            args += ["--status", status.rawValue]
        }
        if let title {
            args += ["--title", title]
        }
        if let type {
            args += ["--type", type]
        }
        if let priority {
            args += ["--priority", priority.label]
        }
        if let description {
            args += ["--description", description]
        }
        if let parent {
            args += ["--parent", parent]
        }
        let output = try await runner.run(
            executable: pbPath, arguments: args, workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
    }

    /// Close an issue.
    func closeIssue(in project: Project, issueID: String) async throws {
        let output = try await runner.run(
            executable: pbPath,
            arguments: ["close", issueID],
            workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
    }

    /// Reopen a closed issue.
    func reopenIssue(in project: Project, issueID: String) async throws {
        let output = try await runner.run(
            executable: pbPath,
            arguments: ["reopen", issueID],
            workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
    }

    // MARK: - Comments

    /// Add a comment to an issue.
    func addComment(in project: Project, issueID: String, body: String) async throws {
        let output = try await runner.run(
            executable: pbPath,
            arguments: ["comment", issueID, "--body", body],
            workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
    }

    // MARK: - Dependencies

    /// Create a dependency between two issues.
    func addDependency(
        in project: Project,
        from issueA: String,
        to issueB: String,
        type: String? = nil
    ) async throws {
        var args = ["dep", "add", issueA, issueB]
        if let type {
            args += ["--type", type]
        }
        let output = try await runner.run(
            executable: pbPath, arguments: args, workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
    }

    /// Remove a dependency.
    func removeDependency(in project: Project, from issueA: String, to issueB: String, type: String? = nil) async throws {
        var args = ["dep", "rm", issueA, issueB]
        if let type {
            args += ["--type", type]
        }
        let output = try await runner.run(
            executable: pbPath,
            arguments: args,
            workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
    }

    /// Fetch the dependency tree for an issue.
    func dependencyTree(in project: Project, issueID: String) async throws -> DepNode {
        let output = try await runner.run(
            executable: pbPath,
            arguments: ["dep", "tree", issueID],
            workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
        guard let node = textParser.parseDepTree(output.stdout) else {
            throw PBError.parseError(detail: "Failed to parse dependency tree")
        }
        return node
    }

    // MARK: - Queries

    /// List issues with no open blocking dependencies.
    func readyIssues(in project: Project) async throws -> [Issue] {
        let output = try await runner.run(
            executable: pbPath,
            arguments: ["ready", "--json"],
            workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
        return try jsonParser.parseReadyList(output.stdout)
    }

    /// Fetch event log.
    func eventLog(
        in project: Project,
        limit: Int? = nil,
        since: Date? = nil,
        until: Date? = nil,
        noGit: Bool = true
    ) async throws -> [Event] {
        var args = ["log", "--json", "--no-pager"]
        if noGit {
            args.append("--no-git")
        }
        if let limit {
            args += ["--limit", "\(limit)"]
        }
        if let since {
            args += ["--since", DateFormatting.rfc3339DecoderNoFraction.string(from: since)]
        }
        if let until {
            args += ["--until", DateFormatting.rfc3339DecoderNoFraction.string(from: until)]
        }
        let output = try await runner.run(
            executable: pbPath, arguments: args, workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
        return try jsonParser.parseEventLog(output.stdout)
    }

    // MARK: - ID Management

    /// Rename a single issue.
    func renameIssue(in project: Project, oldID: String, newID: String) async throws {
        let output = try await runner.run(
            executable: pbPath,
            arguments: ["rename", oldID, newID],
            workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
    }

    /// Batch rename issues to a new prefix.
    func renamePrefix(in project: Project, prefix: String, scope: RenamePrefixScope) async throws {
        var args = ["rename-prefix"]
        switch scope {
        case .open: args.append("--open")
        case .full: args.append("--full")
        }
        args.append(prefix)
        let output = try await runner.run(
            executable: pbPath, arguments: args, workingDirectory: project.path
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
    }

    // MARK: - Meta

    /// Get the pb version string.
    func version() async throws -> String {
        let output = try await runner.run(
            executable: pbPath,
            arguments: ["version"],
            workingDirectory: FileManager.default.currentDirectoryPath
        )
        guard output.exitCode == 0 else {
            throw PBError.commandFailed(stderr: output.stderr, exitCode: output.exitCode)
        }
        return textParser.parseVersion(output.stdout)
    }
}
