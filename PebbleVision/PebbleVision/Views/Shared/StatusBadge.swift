// StatusBadge.swift
// PebbleVision

import SwiftUI

struct StatusBadge: View {
    let status: IssueStatus

    private var color: Color {
        switch status {
        case .open: .blue
        case .inProgress: .orange
        case .closed: .green
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(color, in: Capsule())
    }
}

#Preview {
    HStack(spacing: 8) {
        StatusBadge(status: .open)
        StatusBadge(status: .inProgress)
        StatusBadge(status: .closed)
    }
    .padding()
}
