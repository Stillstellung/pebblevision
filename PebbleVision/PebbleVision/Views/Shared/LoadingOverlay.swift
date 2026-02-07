// LoadingOverlay.swift
// PebbleVision

import SwiftUI

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
            ProgressView()
                .scaleEffect(1.2)
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .ignoresSafeArea()
    }
}

extension View {
    func loadingOverlay(isLoading: Bool) -> some View {
        overlay {
            if isLoading {
                LoadingOverlay()
            }
        }
    }
}

#Preview {
    Text("Content behind overlay")
        .frame(width: 300, height: 200)
        .loadingOverlay(isLoading: true)
}
