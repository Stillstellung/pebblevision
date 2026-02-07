// DepNodeRowView.swift
// PebbleVision

import SwiftUI

struct DepNodeRowView: View {
    let node: DepNode

    var body: some View {
        HStack(spacing: 6) {
            // Status badge (small colored circle)
            Circle()
                .fill(statusColor(node.issue.status))
                .frame(width: 8, height: 8)
                .help(node.issue.status.displayName)

            // Issue ID
            Text(node.issue.id)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            // Priority badge
            Text(node.issue.priority.label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(priorityColor(node.issue.priority), in: Capsule())

            // Title
            Text(node.issue.title)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func statusColor(_ status: IssueStatus) -> Color {
        switch status {
        case .open: .gray
        case .inProgress: .yellow
        case .closed: .green
        }
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .p0: .red
        case .p1: .purple
        case .p2: .orange
        case .p3: .blue
        case .p4: .cyan
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleIssue = Issue(
        id: "pv-abc",
        title: "Fix login flow",
        description: "",
        issueType: "bug",
        status: .open,
        priority: .p1,
        deps: []
    )
    let node = DepNode(issue: sampleIssue, dependencies: [])
    DepNodeRowView(node: node)
        .padding()
}
