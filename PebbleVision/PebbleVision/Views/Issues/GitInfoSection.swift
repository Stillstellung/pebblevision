// GitInfoSection.swift
// PebbleVision

import SwiftUI

/// Shows git commits and branches associated with an issue.
struct GitInfoSection: View {
    let issue: Issue
    @Bindable var viewModel: IssueDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Git Activity")
                .font(.headline)

            branchesSubsection
            commitsSubsection

            if !viewModel.hasGitRemote {
                Label("No remote configured — PR info unavailable", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: issue.id) {
            await viewModel.fetchGitInfo(for: issue.id)
        }
    }

    @ViewBuilder
    private var branchesSubsection: some View {
        if !viewModel.gitBranches.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Branches")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.gitBranches, id: \.self) { branch in
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(branch)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var commitsSubsection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Commits")
                .font(.callout)
                .foregroundStyle(.secondary)

            if viewModel.gitCommits.isEmpty {
                Text("No commits found")
                    .foregroundStyle(.tertiary)
                    .italic()
                    .font(.caption)
            } else {
                ForEach(viewModel.gitCommits) { commit in
                    commitRow(commit)
                }
            }
        }
    }

    @ViewBuilder
    private func commitRow(_ commit: GitCommit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(commit.shortSHA)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.blue)
                Text(commit.message)
                    .font(.caption)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Label(commit.author, systemImage: "person")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(commit.date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
    }
}
