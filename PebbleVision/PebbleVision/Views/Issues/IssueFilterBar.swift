// IssueFilterBar.swift
// PebbleVision

import SwiftUI

struct IssueFilterBar: View {
    @Bindable var viewModel: IssueListViewModel

    private let commonTypes = ["task", "bug", "feature", "epic", "chore"]

    var body: some View {
        HStack(spacing: 12) {
            // Status filter as a single multi-select menu
            Menu {
                ForEach(IssueStatus.allCases, id: \.self) { status in
                    Button {
                        if viewModel.statusFilter.contains(status) {
                            viewModel.statusFilter.remove(status)
                        } else {
                            viewModel.statusFilter.insert(status)
                        }
                        viewModel.showAll = false
                    } label: {
                        HStack {
                            Text(status.displayName)
                            if viewModel.statusFilter.contains(status) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button("Show All") {
                    viewModel.showAll = true
                    viewModel.statusFilter = Set(IssueStatus.allCases)
                }
            } label: {
                Label(statusLabel, systemImage: "line.3.horizontal.decrease.circle")
            }
            .lineLimit(1)

            // Type filter
            Picker("Type", selection: Binding(
                get: { viewModel.typeFilter ?? "__all__" },
                set: { viewModel.typeFilter = $0 == "__all__" ? nil : $0 }
            )) {
                Text("All Types").tag("__all__")
                Divider()
                ForEach(commonTypes, id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            }
            .lineLimit(1)

            // Priority filter
            Picker("Priority", selection: Binding(
                get: { viewModel.priorityFilter?.rawValue ?? -1 },
                set: { viewModel.priorityFilter = $0 == -1 ? nil : Priority(rawValue: $0) }
            )) {
                Text("Any Priority").tag(-1)
                Divider()
                ForEach(Priority.allCases, id: \.self) { p in
                    Text(p.label).tag(p.rawValue)
                }
            }
            .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var statusLabel: String {
        if viewModel.statusFilter.count == IssueStatus.allCases.count {
            return "All Statuses"
        }
        return viewModel.statusFilter.map(\.displayName).sorted().joined(separator: ", ")
    }
}

#Preview {
    IssueFilterBar(viewModel: IssueListViewModel(client: PreviewData.client, project: PreviewData.project))
        .frame(width: 500)
        .padding()
}
