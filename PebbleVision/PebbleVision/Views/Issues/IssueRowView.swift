// IssueRowView.swift
// PebbleVision

import SwiftUI

struct IssueRowView: View {
    let issue: Issue

    var body: some View {
        HStack(spacing: 8) {
            StatusBadge(status: issue.status)

            Text(issue.id)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(issue.title)
                .font(.callout)
                .lineLimit(1)

            Spacer()

            PriorityBadge(priority: issue.priority)

            TypeBadge(issueType: issue.issueType)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(PreviewData.issues) { issue in
            IssueRowView(issue: issue)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            Divider()
        }
    }
    .frame(width: 600)
}
