// WorkerInfoService.swift
// PebbleVision

import Foundation

/// Discovers claude-team worker branches and worktrees associated with an issue.
actor WorkerInfoService {
    private let runner = ProcessRunner()

    /// Find a worker branch/worktree matching the given issue ID.
    func discoverWorker(for issueID: String, in project: Project) async -> WorkerInfo? {
        let dir = project.path

        // Find branches matching the issue ID
        guard let branchOutput = await runGit(["branch", "--all", "--list", "*\(issueID)*"], in: dir),
              !branchOutput.isEmpty else {
            return nil
        }

        // Take the first matching branch, strip leading whitespace and * marker
        let branches = branchOutput.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "* ", with: "") }
            .filter { !$0.isEmpty }

        guard let branch = branches.first else { return nil }

        // Check if it's a worktree
        let isWorktree = await checkWorktree(for: issueID, in: dir)

        // Get last commit on this branch
        let commitInfo = await fetchLastCommit(on: branch, in: dir)

        return WorkerInfo(
            branchName: branch,
            isWorktree: isWorktree,
            lastCommitSHA: commitInfo?.sha,
            lastCommitMessage: commitInfo?.message,
            lastCommitAuthor: commitInfo?.author,
            lastCommitDate: commitInfo?.date
        )
    }

    private func checkWorktree(for issueID: String, in dir: String) async -> Bool {
        guard let output = await runGit(["worktree", "list"], in: dir) else { return false }
        return output.contains(issueID)
    }

    private struct CommitInfo {
        let sha: String
        let message: String
        let author: String
        let date: Date?
    }

    private func fetchLastCommit(on branch: String, in dir: String) async -> CommitInfo? {
        guard let output = await runGit(
            ["log", "-1", "--format=%h|%s|%an|%aI", branch],
            in: dir
        ), !output.isEmpty else {
            return nil
        }

        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|")
        guard parts.count >= 4 else { return nil }

        let sha = parts[0]
        let message = parts[1]
        let author = parts[2]
        let dateStr = parts[3...].joined(separator: "|") // ISO date may not have |, but be safe
        let date = ISO8601DateFormatter().date(from: dateStr)

        return CommitInfo(sha: sha, message: message, author: author, date: date)
    }

    private func runGit(_ arguments: [String], in dir: String) async -> String? {
        do {
            let result = try await runner.run(
                executable: "git",
                arguments: arguments,
                workingDirectory: dir
            )
            guard result.exitCode == 0 else { return nil }
            return result.stdout
        } catch {
            return nil
        }
    }
}
