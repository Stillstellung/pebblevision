// SidebarView.swift
// PebbleVision
//
// Left sidebar with project selector and section navigation.

import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            ProjectSelectorView()
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Divider()

            List(selection: $appState.selectedSection) {
                Section("Navigation") {
                    ForEach(AppState.Section.allCases) { section in
                        Label(section.rawValue, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "gear")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 180, idealWidth: 220)
    }
}

#Preview {
    NavigationSplitView {
        SidebarView()
    } detail: {
        Text("Detail")
    }
    .environment(AppState())
    .environment(ProjectStore())
    .environment(PBClient())
}
