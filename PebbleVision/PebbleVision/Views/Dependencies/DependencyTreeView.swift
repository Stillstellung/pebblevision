// DependencyTreeView.swift
// PebbleVision

import SwiftUI

struct DependencyTreeView: View {
    @State private var viewModel: DependencyTreeViewModel

    init(client: PBClient, project: Project) {
        _viewModel = State(initialValue: DependencyTreeViewModel(client: client, project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Input bar
            HStack {
                TextField("Issue ID (e.g. pv-abc)", text: $viewModel.selectedIssueID)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await viewModel.fetchTree(for: viewModel.selectedIssueID) }
                    }

                Button("Show Tree") {
                    Task { await viewModel.fetchTree(for: viewModel.selectedIssueID) }
                }
                .disabled(viewModel.selectedIssueID.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            Divider()

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading dependency tree...")
                Spacer()
            } else if let error = viewModel.error {
                errorView(error)
            } else if let root = viewModel.rootNode {
                treeContent(root)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 300)
    }

    @ViewBuilder
    private func treeContent(_ root: DepNode) -> some View {
        List {
            // Root node
            DepNodeRowView(node: root)
                .font(.headline)

            // Recursive children via OutlineGroup
            if !root.dependencies.isEmpty {
                OutlineGroup(root.dependencies, children: \.optionalDependencies) { node in
                    DepNodeRowView(node: node)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Enter an issue ID to view its dependency tree")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private func errorView(_ error: PBError) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await viewModel.fetchTree(for: viewModel.selectedIssueID) }
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - OutlineGroup support

private extension DepNode {
    /// Returns dependencies as optional for OutlineGroup children parameter.
    var optionalDependencies: [DepNode]? {
        dependencies.isEmpty ? nil : dependencies
    }
}

// MARK: - Preview

#Preview {
    let client = PBClient()
    let project = Project(name: "Preview", path: "/tmp", prefix: "pv")
    DependencyTreeView(client: client, project: project)
        .frame(width: 500, height: 400)
}
