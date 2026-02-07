// IssueCreateSheet.swift
// PebbleVision

import SwiftUI

struct IssueCreateSheet: View {
    @Bindable var viewModel: IssueCreateViewModel
    @Environment(\.dismiss) private var dismiss
    var onCreated: ((String) -> Void)?

    @FocusState private var titleFocused: Bool

    private let commonTypes = ["task", "bug", "feature", "epic", "chore"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Issue")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Fields
            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    TextField("Issue title", text: $viewModel.title)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFocused)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $viewModel.issueType) {
                            ForEach(commonTypes, id: \.self) { type in
                                Text(type.capitalized).tag(type)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Priority")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $viewModel.priority) {
                            ForEach(Priority.allCases, id: \.self) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $viewModel.description)
                        .font(.body)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Divider()

                // Relationships
                IssueSearchField(
                    label: "Parent Issues",
                    availableIssues: viewModel.availableIssues,
                    selectedIDs: $viewModel.selectedParents
                )

                IssueSearchField(
                    label: "Blocked By (Dependencies)",
                    availableIssues: viewModel.availableIssues,
                    selectedIDs: $viewModel.selectedDeps
                )
            }
            .padding()
            }

            if let error = viewModel.error {
                ErrorBanner(
                    message: error.localizedDescription,
                    onDismiss: { viewModel.error = nil }
                )
                .padding(.bottom, 8)
            }

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    Task {
                        if let newID = await viewModel.submit() {
                            onCreated?(newID)
                            dismiss()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isValid || viewModel.isSubmitting)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 500)
        .environment(\.layoutDirection, .leftToRight)
        .task {
            await viewModel.fetchAvailableIssues()
        }
        .onAppear {
            titleFocused = true
        }
    }
}

#Preview {
    IssueCreateSheet(
        viewModel: IssueCreateViewModel(client: PreviewData.client, project: PreviewData.project)
    )
}
