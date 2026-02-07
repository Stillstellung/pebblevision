// IssueTypeahead.swift
// PebbleVision
//
// Single-select typeahead for adding one issue at a time.
// Used in issue detail view for adding parents, children, and deps.

import SwiftUI

struct IssueTypeahead: View {
    let placeholder: String
    let availableIssues: [Issue]
    let excludeIDs: Set<String>
    let onSelect: (String) -> Void

    @State private var searchText = ""
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool

    private var filteredIssues: [Issue] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return availableIssues.filter { issue in
            !excludeIDs.contains(issue.id) &&
            (issue.id.lowercased().contains(query) || issue.title.lowercased().contains(query))
        }
        .prefix(6)
        .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .focused($isFocused)
                .onChange(of: searchText) { _, newValue in
                    showSuggestions = !newValue.isEmpty
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showSuggestions = false
                        }
                    }
                }
                .onSubmit {
                    // If the text exactly matches an issue ID, add it directly
                    let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        onSelect(trimmed)
                        searchText = ""
                        showSuggestions = false
                    }
                }

            if showSuggestions && !filteredIssues.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredIssues) { issue in
                        Button {
                            onSelect(issue.id)
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
