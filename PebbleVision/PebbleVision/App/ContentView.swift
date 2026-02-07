// ContentView.swift
// PebbleVision
//
// Main three-column NavigationSplitView layout.

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectStore.self) private var projectStore
    @Environment(PBClient.self) private var pbClient

    @State private var pbVersion: String = ""
    @State private var issueCount: Int = 0
    @State private var issueListVM: IssueListViewModel?
    @State private var issueDetailVM: IssueDetailViewModel?

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } content: {
            contentForSection(appState.selectedSection, selectedIssueID: $appState.selectedIssueID)
                .safeAreaInset(edge: .bottom) {
                    statusBar
                }
                .navigationSplitViewColumnWidth(min: 350, ideal: 450, max: 600)
        } detail: {
            if let issueID = appState.selectedIssueID,
               let vm = issueDetailVM {
                IssueDetailView(viewModel: vm, issueID: issueID, onNavigateToIssue: { id in
                    appState.selectedIssueID = id
                })
            } else {
                EmptyStateView(message: "Select an issue")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 4) {
                    Button {
                        appState.requestRefresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh (⌘R)")

                    Button {
                        appState.showCreateSheet = true
                    } label: {
                        Label("New Issue", systemImage: "plus")
                    }
                    .help("New Issue (⌘N)")
                }
            }
        }
        .sheet(isPresented: $appState.showCreateSheet) {
            if let project = projectStore.selectedProject {
                IssueCreateSheet(
                    viewModel: IssueCreateViewModel(client: pbClient, project: project),
                    onCreated: { newID in
                        appState.selectedIssueID = newID
                        appState.requestRefresh()
                    }
                )
            }
        }
        .task {
            await fetchVersion()
        }
        .onChange(of: projectStore.selectedProject) { _, _ in
            appState.selectedIssueID = nil
            rebuildViewModels()
            Task { await refreshIssueCount() }
        }
        .onAppear {
            rebuildViewModels()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pbRefreshRequested)) { _ in
            Task { await refreshIssueCount() }
        }
        .task {
            await refreshIssueCount()
        }
    }

    @ViewBuilder
    private func contentForSection(_ section: AppState.Section, selectedIssueID: Binding<String?>) -> some View {
        if let project = projectStore.selectedProject {
            Group {
                switch section {
                case .issues:
                    if let vm = issueListVM {
                        IssueListView(viewModel: vm, selectedIssueID: selectedIssueID, onNewIssue: {
                            appState.showCreateSheet = true
                        })
                    }
                case .ready:
                    ReadyView(client: pbClient, project: project)
                case .depTree:
                    DependencyTreeView(client: pbClient, project: project)
                case .eventLog:
                    EventLogView(client: pbClient, project: project)
                }
            }
            .id(project.id)
        } else {
            EmptyStateView(icon: "folder", message: "Select a project to get started")
        }
    }

    private func rebuildViewModels() {
        guard let project = projectStore.selectedProject else {
            issueListVM = nil
            issueDetailVM = nil
            return
        }
        issueListVM = IssueListViewModel(client: pbClient, project: project)
        issueDetailVM = IssueDetailViewModel(client: pbClient, project: project)
    }

    private var statusBar: some View {
        HStack {
            HStack(spacing: 4) {
                Text("\(issueCount) issues")
                if let lastRefresh = appState.lastRefresh {
                    Text("·")
                    Text("Last refreshed \(lastRefresh.formatted(.relative(presentation: .named)))")
                }
            }
            .foregroundStyle(.secondary)

            Spacer()

            if !pbVersion.isEmpty {
                Text("pb \(pbVersion)")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func fetchVersion() async {
        do {
            pbVersion = try await pbClient.version()
        } catch {
            pbVersion = ""
        }
    }

    private func refreshIssueCount() async {
        guard let project = projectStore.selectedProject else {
            issueCount = 0
            return
        }
        do {
            let issues = try await pbClient.listIssues(in: project)
            issueCount = issues.count
        } catch {
            issueCount = 0
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(ProjectStore())
        .environment(PBClient())
        .frame(width: 900, height: 600)
}
