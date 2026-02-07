// GitInfoService.swift
// PebbleVision

import Foundation

/// Queries git history for commits and branches associated with an issue.
actor GitInfoService {
    private let runner = ProcessRunner()

    /// Find all commits whose message references the given issue ID.
    func findCommits(for issueID: String, in project: Project) async -> [GitCommit] {
        let dir = project.path

        guard let output = await runGit(
            ["log", "--all", "--grep=\(issueID)", "--format=%H|%h|%s|%an|%aI"],
            in: dir
        ), !output.isEmpty else {
            return []
        }

        return parseCommits(from: output)
    }

    /// Find branches whose name contains the issue ID.
    func findBranches(for issueID: String, in project: Project) async -> [String] {
        let dir = project.path

        guard let output = await runGit(
            ["branch", "--all", "--list", "*\(issueID)*"],
            in: dir
        ), !output.isEmpty else {
            return []
        }

        return output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "* ", with: "") }
            .filter { !$0.isEmpty }
    }

    /// Check whether any git remote is configured.
    func hasRemote(in project: Project) async -> Bool {
        guard let output = await runGit(["remote"], in: project.path) else { return false }
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func parseCommits(from output: String) -> [GitCommit] {
        let formatter = ISO8601DateFormatter()
        return output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 5 else { return nil }
                let fullSHA = parts[0]
                let shortSHA = parts[1]
                let message = parts[2]
                let author = parts[3]
                let dateStr = parts[4...].joined(separator: "|")
                let date = formatter.date(from: dateStr) ?? Date.distantPast
                return GitCommit(
                    id: fullSHA,
                    shortSHA: shortSHA,
                    message: message,
                    author: author,
                    date: date
                )
            }
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
