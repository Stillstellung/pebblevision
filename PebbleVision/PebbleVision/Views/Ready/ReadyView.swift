// ReadyView.swift
// PebbleVision

import SwiftUI

struct ReadyView: View {
    @State private var viewModel: ReadyViewModel

    init(client: PBClient, project: Project) {
        _viewModel = State(initialValue: ReadyViewModel(client: client, project: project))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading ready issues...")
                    Spacer()
                }
            } else if let error = viewModel.error {
                errorView(error)
            } else if viewModel.sortedReadyIssues.isEmpty {
                emptyState
            } else {
                List(viewModel.sortedReadyIssues) { issue in
                    ReadyIssueRow(issue: issue)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 300)
        .task {
            await viewModel.fetchReady()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await viewModel.fetchReady()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                IssueSortMenu(sortField: $viewModel.sortField, sortAscending: $viewModel.sortAscending)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.fetchReady() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No unblocked issues")
                .foregroundStyle(.secondary)
            Text("All issues have open blocking dependencies, or there are no issues.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private func errorView(_ error: PBError) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await viewModel.fetchReady() }
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Ready Issue Row (inline equivalent of IssueRowView)

private struct ReadyIssueRow: View {
    let issue: Issue

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .help(issue.status.displayName)

            // Issue ID
            Text(issue.id)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            // Priority badge
            Text(issue.priority.label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(issue.priority == .p2 ? .black : .white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(priorityColor, in: Capsule())

            // Type chip
            if !issue.issueType.isEmpty {
                Text(issue.issueType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }

            // Title
            Text(issue.title)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch issue.status {
        case .open: .gray
        case .inProgress: .yellow
        case .closed: .green
        }
    }

    private var priorityColor: Color {
        switch issue.priority {
        case .p0: .red
        case .p1: .pink
        case .p2: .yellow
        case .p3: .blue
        case .p4: .teal
        }
    }
}

// MARK: - Preview

#Preview {
    let client = PBClient()
    let project = Project(name: "Preview", path: "/tmp", prefix: "pv")
    ReadyView(client: client, project: project)
        .frame(width: 500, height: 400)
}
