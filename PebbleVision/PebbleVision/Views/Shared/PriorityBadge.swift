// PriorityBadge.swift
// PebbleVision

import SwiftUI

struct PriorityBadge: View {
    let priority: Priority

    private var color: Color {
        switch priority {
        case .p0: .red
        case .p1: .pink
        case .p2: .yellow
        case .p3: .blue
        case .p4: .teal
        }
    }

    private var textColor: Color {
        switch priority {
        case .p2: .black
        default: .white
        }
    }

    var body: some View {
        Text(priority.label)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(textColor)
            .background(color, in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    HStack(spacing: 8) {
        ForEach(Priority.allCases, id: \.self) { p in
            PriorityBadge(priority: p)
        }
    }
    .padding()
}
