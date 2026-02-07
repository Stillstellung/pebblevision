// ProjectSelectorView.swift
// PebbleVision
//
// Dropdown for selecting, adding, and initializing projects.

import SwiftUI
import AppKit

struct ProjectSelectorView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(PBClient.self) private var pbClient

    @State private var projectManager: ProjectManagerViewModel?
    @State private var showInitPrefixAlert = false
    @State private var initPrefix = ""
    @State private var pendingInitPath: String?

    var body: some View {
        Menu {
            if projectStore.projects.isEmpty {
                Text("No projects")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(projectStore.projects) { project in
                    Button {
                        projectStore.selectedProject = project
                    } label: {
                        HStack {
                            Text(project.name)
                            if project.id == projectStore.selectedProject?.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Add Existing Project...") {
                addExistingProject()
            }

            Button("Init New Project...") {
                initNewProject()
            }
        } label: {
            HStack {
                Image(systemName: "folder")
                Text(projectStore.selectedProject?.name ?? "Select Project")
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .alert("Project Prefix", isPresented: $showInitPrefixAlert) {
            TextField("Prefix (e.g. pv)", text: $initPrefix)
            Button("Init") {
                guard let path = pendingInitPath else { return }
                let mgr = getProjectManager()
                Task {
                    await mgr.initProject(at: path, prefix: initPrefix.isEmpty ? nil : initPrefix)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingInitPath = nil
                initPrefix = ""
            }
        } message: {
            Text("Enter an issue ID prefix for this project, or leave blank for the default.")
        }
    }

    private func getProjectManager() -> ProjectManagerViewModel {
        if let mgr = projectManager { return mgr }
        let mgr = ProjectManagerViewModel(pbClient: pbClient, projectStore: projectStore)
        projectManager = mgr
        return mgr
    }

    private func addExistingProject() {
        let panel = NSOpenPanel()
        panel.title = "Select Project Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let path = url.path
        guard projectStore.validateProjectPath(path) else {
            // Could show an alert here; for now the ProjectManagerViewModel sets its error
            let mgr = getProjectManager()
            Task { await mgr.addExistingProject(path: path) }
            return
        }

        let mgr = getProjectManager()
        Task { await mgr.addExistingProject(path: path) }
    }

    private func initNewProject() {
        let panel = NSOpenPanel()
        panel.title = "Select Folder for New Project"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        pendingInitPath = url.path
        initPrefix = ""
        showInitPrefixAlert = true
    }
}

#Preview {
    ProjectSelectorView()
        .environment(ProjectStore())
        .environment(PBClient())
        .frame(width: 220)
        .padding()
}
