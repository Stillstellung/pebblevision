// IssueSearchField.swift
// PebbleVision
//
// Typeahead field for selecting issues by ID or title.

import SwiftUI

struct IssueSearchField: View {
    let label: String
    let availableIssues: [Issue]
    @Binding var selectedIDs: [String]

    @State private var searchText = ""
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool

    private var filteredIssues: [Issue] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return availableIssues.filter { issue in
            !selectedIDs.contains(issue.id) &&
            (issue.id.lowercased().contains(query) || issue.title.lowercased().contains(query))
        }
        .prefix(6)
        .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)

            // Selected chips
            if !selectedIDs.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(selectedIDs, id: \.self) { id in
                        selectedChip(id: id)
                    }
                }
            }

            // Search field with suggestions
            VStack(alignment: .leading, spacing: 0) {
                TextField("Search by ID or title...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onChange(of: searchText) { _, newValue in
                        showSuggestions = !newValue.isEmpty
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused {
                            // Delay hiding so click on suggestion registers
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showSuggestions = false
                            }
                        }
                    }

                if showSuggestions && !filteredIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredIssues) { issue in
                            Button {
                                selectedIDs.append(issue.id)
                                searchText = ""
                                showSuggestions = false
                            } label: {
                                HStack(spacing: 8) {
                                    Text(issue.id)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    Text(issue.title)
                                        .font(.callout)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Spacer()
                                    StatusBadge(status: issue.status)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if issue.id != filteredIssues.last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
            }
        }
    }

    @ViewBuilder
    private func selectedChip(id: String) -> some View {
        let issue = availableIssues.first(where: { $0.id == id })
        HStack(spacing: 4) {
            Text(id)
                .font(.system(.caption, design: .monospaced))
            if let title = issue?.title {
                Text("— \(title)")
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            Button {
                selectedIDs.removeAll(where: { $0 == id })
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.1), in: Capsule())
    }
}
