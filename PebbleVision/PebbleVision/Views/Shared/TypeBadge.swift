// TypeBadge.swift
// PebbleVision

import SwiftUI

struct TypeBadge: View {
    let issueType: String

    private var color: Color {
        switch issueType.lowercased() {
        case "bug": .red
        case "epic": .purple
        case "feature": .blue
        case "chore": .gray
        case "task": .secondary
        default: .gray
        }
    }

    var body: some View {
        Text(issueType)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    HStack(spacing: 8) {
        TypeBadge(issueType: "bug")
        TypeBadge(issueType: "epic")
        TypeBadge(issueType: "feature")
        TypeBadge(issueType: "chore")
        TypeBadge(issueType: "task")
        TypeBadge(issueType: "custom-type")
    }
    .padding()
}
