// ErrorBanner.swift
// PebbleVision

import SwiftUI

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)

            Text(message)
                .font(.callout)
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            if let onRetry {
                Button {
                    onRetry()
                } label: {
                    Text("Retry")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.red.gradient, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 12) {
        ErrorBanner(
            message: "Failed to load issues",
            onDismiss: {},
            onRetry: {}
        )
        ErrorBanner(
            message: "Connection failed: timeout after 30 seconds",
            onDismiss: {}
        )
    }
    .padding()
}
