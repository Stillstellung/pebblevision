// SettingsView.swift
// PebbleVision

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ProjectsSettingsTab()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 360)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @AppStorage("pbPath") private var pbPath: String = "/usr/local/bin/pb"
    @State private var showFilePicker = false

    var body: some View {
        Form {
            Section("pb CLI") {
                HStack {
                    TextField("Path to pb binary", text: $pbPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        showFilePicker = true
                    }
                }
                .fileImporter(
                    isPresented: $showFilePicker,
                    allowedContentTypes: [.unixExecutable, .item],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        pbPath = url.path
                    }
                }

                Text("Path to the pebbles CLI binary used for all operations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Defaults") {
                Text("Default project will be set from the Projects tab.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Projects Tab

private struct ProjectsSettingsTab: View {
    @State private var store = ProjectStore()
    @State private var showFolderPicker = false
    @State private var editingPrefix: [UUID: String] = [:]
    @State private var showInitSheet = false
    @State private var initPath = ""
    @State private var initPrefix = ""

    var body: some View {
        VStack(spacing: 0) {
            List {
                if store.projects.isEmpty {
                    Text("No projects registered.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(store.projects) { project in
                        projectRow(project)
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button("Add Existing...") {
                    showFolderPicker = true
                }
                .fileImporter(
                    isPresented: $showFolderPicker,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        addProject(at: url.path)
                    }
                }

                Button("Init New...") {
                    showInitSheet = true
                }

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showInitSheet) {
            initProjectSheet
        }
    }

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .fontWeight(.medium)
                Text(project.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("Prefix:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("prefix", text: Binding(
                    get: { editingPrefix[project.id] ?? project.prefix },
                    set: { editingPrefix[project.id] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .onSubmit {
                    if let newPrefix = editingPrefix[project.id] {
                        var updated = project
                        updated.prefix = newPrefix
                        store.updateProject(updated)
                        editingPrefix.removeValue(forKey: project.id)
                    }
                }
            }

            Button(role: .destructive) {
                store.removeProject(id: project.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var initProjectSheet: some View {
        VStack(spacing: 16) {
            Text("Initialize New Project")
                .font(.headline)

            Form {
                TextField("Project Path:", text: $initPath)
                TextField("Prefix (optional):", text: $initPrefix)
            }

            HStack {
                Button("Cancel") {
                    showInitSheet = false
                }
                Spacer()
                Button("Initialize") {
                    let project = Project(
                        name: URL(fileURLWithPath: initPath).lastPathComponent,
                        path: initPath,
                        prefix: initPrefix.isEmpty ? URL(fileURLWithPath: initPath).lastPathComponent : initPrefix
                    )
                    store.addProject(project)
                    initPath = ""
                    initPrefix = ""
                    showInitSheet = false
                }
                .disabled(initPath.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func addProject(at path: String) {
        let name = URL(fileURLWithPath: path).lastPathComponent
        let project = Project(
            name: name,
            path: path,
            prefix: name
        )
        store.addProject(project)
    }
}

// MARK: - About Tab

private struct AboutSettingsTab: View {
    @State private var pbVersion: String = "Checking..."

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("PebbleVision")
                .font(.title)
                .fontWeight(.bold)

            Text("A native macOS GUI for the pebbles issue tracker")
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("App Version:")
                        .foregroundStyle(.secondary)
                    Text("1.0.0")
                }
                GridRow {
                    Text("pb Version:")
                        .foregroundStyle(.secondary)
                    Text(pbVersion)
                }
            }

            Link("pebbles on GitHub",
                 destination: URL(string: "https://github.com/Martian-Engineering/pebbles")!)
                .font(.caption)

            Spacer()
        }
        .padding()
        .task {
            await fetchPBVersion()
        }
    }

    private func fetchPBVersion() async {
        let client = PBClient()
        do {
            pbVersion = try await client.version()
        } catch {
            pbVersion = "Not found"
        }
    }
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView()
}

#Preview("General") {
    GeneralSettingsTab()
        .frame(width: 500, height: 300)
}

#Preview("About") {
    AboutSettingsTab()
        .frame(width: 500, height: 360)
}
