// WorkerInfoSection.swift
// PebbleVision

import SwiftUI

/// Shows claude-team worker branch and worktree info for an in-progress issue.
struct WorkerInfoSection: View {
    let issue: Issue
    @Bindable var viewModel: IssueDetailViewModel

    var body: some View {
        if issue.status == .inProgress {
            VStack(alignment: .leading, spacing: 8) {
                Text("Worker")
                    .font(.headline)

                if let info = viewModel.workerInfo {
                    workerDetails(info)
                } else {
                    Text("No active worker branch")
                        .foregroundStyle(.tertiary)
                        .italic()
                        .font(.callout)
                }
            }
            .task(id: issue.id) {
                await viewModel.fetchWorkerInfo(for: issue.id)
            }
        }
    }

    @ViewBuilder
    private func workerDetails(_ info: WorkerInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.secondary)
                Text(info.branchName)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)

                if info.isWorktree {
                    Text("worktree")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                }
            }

            if let sha = info.lastCommitSHA {
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(sha)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let msg = info.lastCommitMessage {
                        Text(msg)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    if let author = info.lastCommitAuthor {
                        Label(author, systemImage: "person")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let date = info.lastCommitDate {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }
}
