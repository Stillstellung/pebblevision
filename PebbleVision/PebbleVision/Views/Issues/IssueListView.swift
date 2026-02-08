// IssueListView.swift
// PebbleVision

import SwiftUI

struct IssueListView: View {
    @Bindable var viewModel: IssueListViewModel
    @Binding var selectedIssueID: String?
    var onNewIssue: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search issues...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            IssueFilterBar(viewModel: viewModel)
            Divider()

            if let error = viewModel.error {
                ErrorBanner(
                    message: error.localizedDescription,
                    onDismiss: { viewModel.error = nil },
                    onRetry: { Task { await viewModel.fetchIssues() } }
                )
                .padding(.top, 8)
            }

            if viewModel.filteredIssues.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    message: viewModel.searchText.isEmpty ? "No issues found" : "No matching issues"
                )
            } else {
                List(viewModel.filteredIssues, selection: $selectedIssueID) { issue in
                    IssueRowView(issue: issue)
                        .tag(issue.id)
                }
                .listStyle(.inset)
            }
        }
        .loadingOverlay(isLoading: viewModel.isLoading)
        .task {
            await viewModel.fetchIssues()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await viewModel.fetchIssues(silent: true)
            }
        }
        .onChange(of: viewModel.statusFilter) { _, _ in
            Task { await viewModel.fetchIssues() }
        }
        .onChange(of: viewModel.typeFilter) { _, _ in
            Task { await viewModel.fetchIssues() }
        }
        .onChange(of: viewModel.priorityFilter) { _, _ in
            Task { await viewModel.fetchIssues() }
        }
        .onChange(of: viewModel.showAll) { _, _ in
            Task { await viewModel.fetchIssues() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pbRefreshRequested)) { _ in
            Task { await viewModel.fetchIssues() }
        }
    }
}

#Preview {
    @Previewable @State var selectedID: String? = nil
    let vm = IssueListViewModel(client: PreviewData.client, project: PreviewData.project)

    IssueListView(viewModel: vm, selectedIssueID: $selectedID)
        .frame(width: 600, height: 400)
        .onAppear {
            vm.issues = PreviewData.issues
        }
}
