// EventRowView.swift
// PebbleVision

import SwiftUI

struct EventRowView: View {
    let event: Event

    var body: some View {
        HStack(spacing: 8) {
            // Timestamp
            Text(formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            // Event type badge (colored chip)
            Text(event.label ?? event.type)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(eventTypeColor(event.type), in: Capsule())
                .frame(width: 100)

            // Issue ID (monospaced)
            Text(event.issueID)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.blue)
                .frame(width: 90, alignment: .leading)

            // Issue title
            if let issueTitle = event.issueTitle {
                Text(issueTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Details summary
            if let details = event.details, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 200, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: event.timestamp)
    }

    private func eventTypeColor(_ type: String) -> Color {
        switch type {
        case "create":          .green
        case "close":           .red
        case "comment":         .blue
        case "status_update":   .orange
        case "dep_add":         .purple
        case "dep_rm":          .pink
        case "rename":          .indigo
        case "title_updated":   .teal
        case "update":          .mint
        default:                .gray
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleEvent = Event(
        line: 1,
        timestamp: Date(),
        type: "create",
        label: "create",
        issueID: "pv-abc",
        issueTitle: "Fix login bug",
        actor: "joel",
        actorDate: "2025-01-20",
        details: "type=bug priority=P1",
        payload: ["title": "Fix login bug", "type": "bug"]
    )
    List {
        EventRowView(event: sampleEvent)
        EventRowView(event: Event(
            line: 2,
            timestamp: Date(),
            type: "status_update",
            label: "status_update",
            issueID: "pv-def",
            issueTitle: "Add dark mode",
            actor: "joel",
            actorDate: "2025-01-21",
            details: "status=in_progress",
            payload: ["status": "in_progress"]
        ))
        EventRowView(event: Event(
            line: 3,
            timestamp: Date(),
            type: "comment",
            label: "comment",
            issueID: "pv-abc",
            issueTitle: "Fix login bug",
            actor: "joel",
            actorDate: "2025-01-21",
            details: "",
            payload: ["body": "Looking into this"]
        ))
    }
    .frame(width: 700, height: 200)
}
