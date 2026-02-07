// EmptyStateView.swift
// PebbleVision

import SwiftUI

struct EmptyStateView: View {
    var icon: String = "tray"
    var message: String = "No items"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(icon: "doc.text.magnifyingglass", message: "No issues found")
        .frame(width: 300, height: 200)
}
