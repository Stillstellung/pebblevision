// WorkerInfo.swift
// PebbleVision

import Foundation

/// Information about a claude-team worker assigned to an issue.
struct WorkerInfo: Sendable {
    var branchName: String
    var isWorktree: Bool
    var lastCommitSHA: String?
    var lastCommitMessage: String?
    var lastCommitAuthor: String?
    var lastCommitDate: Date?
}
