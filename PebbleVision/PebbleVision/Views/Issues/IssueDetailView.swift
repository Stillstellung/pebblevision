// IssueDetailView.swift
// PebbleVision

import SwiftUI

struct IssueDetailView: View {
    @Bindable var viewModel: IssueDetailViewModel
    let issueID: String
    var onNavigateToIssue: ((String) -> Void)?

    @State private var editingDescription = false
    @State private var draftDescription = ""
    @State private var newCommentText = ""
    @State private var showCloseConfirmation = false
    @State private var showEditSheet = false

    var body: some View {
        Group {
            if let issue = viewModel.issue {
                issueContent(issue)
            } else if viewModel.isLoading {
                ProgressView("Loading issue...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                VStack(spacing: 12) {
                    ErrorBanner(
                        message: error.localizedDescription,
                        onDismiss: { viewModel.error = nil },
                        onRetry: { Task { await viewModel.fetchIssue(id: issueID) } }
                    )
                    Spacer()
                }
            } else {
                EmptyStateView(icon: "doc.text", message: "Select an issue")
            }
        }
        .loadingOverlay(isLoading: viewModel.isSaving)
        .task(id: issueID) {
            await viewModel.fetchIssue(id: issueID)
            await viewModel.fetchAvailableIssues()
        }
        .alert("Close Issue", isPresented: $showCloseConfirmation) {
            Button("Close", role: .destructive) {
                Task { await viewModel.closeIssue() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to close this issue?")
        }
        .sheet(isPresented: $showEditSheet) {
            if let issue = viewModel.issue {
                IssueEditSheet(
                    title: issue.title,
                    description: issue.description,
                    onSave: { newTitle, newDesc in
                        Task {
                            await viewModel.updateTitle(newTitle)
                            await viewModel.updateDescription(newDesc)
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func issueContent(_ issue: Issue) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection(issue)
                Divider()
                metadataSection(issue)
                WorkerInfoSection(issue: issue, viewModel: viewModel)
                Divider()
                descriptionSection(issue)
                Divider()
                hierarchySection(issue)
                Divider()
                dependenciesSection(issue)
                Divider()
                commentsSection(issue)
                Divider()
                GitInfoSection(issue: issue, viewModel: viewModel)
            }
            .padding()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(_ issue: Issue) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 6) {
                    Text(issue.id)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(issue.id, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Copy issue ID")
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if issue.status == .closed {
                    Button {
                        Task { await viewModel.reopenIssue() }
                    } label: {
                        Label("Reopen", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        showCloseConfirmation = true
                    } label: {
                        Label("Close", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
        }
    }

    // MARK: - Metadata

    @ViewBuilder
    private func metadataSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metadata")
                .font(.headline)

            HStack(spacing: 16) {
                // Status picker
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { issue.status },
                        set: { newStatus in Task { await viewModel.updateStatus(newStatus) } }
                    )) {
                        ForEach(IssueStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                // Priority picker
                VStack(alignment: .leading, spacing: 2) {
                    Text("Priority")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { issue.priority },
                        set: { newPriority in Task { await viewModel.updatePriority(newPriority) } }
                    )) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                // Type text field
                VStack(alignment: .leading, spacing: 2) {
                    Text("Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TypeTextField(
                        currentType: issue.issueType,
                        onCommit: { newType in Task { await viewModel.updateType(newType) } }
                    )
                }

                Spacer()
            }

            if let created = issue.createdAt {
                HStack(spacing: 16) {
                    Label(created.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let updated = issue.updatedAt {
                        Label("Updated \(updated.formatted(.relative(presentation: .named)))", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Description

    @ViewBuilder
    private func descriptionSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Description")
                    .font(.headline)
                Spacer()
                if editingDescription {
                    HStack(spacing: 8) {
                        Button("Cancel") {
                            editingDescription = false
                        }
                        .controlSize(.small)
                        Button("Save") {
                            Task { await viewModel.updateDescription(draftDescription) }
                            editingDescription = false
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Button {
                        draftDescription = issue.description
                        editingDescription = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if editingDescription {
                TextEditor(text: $draftDescription)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                if issue.description.isEmpty {
                    Text("No description")
                        .foregroundStyle(.tertiary)
                        .italic()
                } else {
                    Text(issue.description)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Hierarchy

    @ViewBuilder
    private func hierarchySection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hierarchy")
                .font(.headline)

            // Parents
            VStack(alignment: .leading, spacing: 4) {
                Text("Parents")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                let parents = issue.parents ?? []
                if parents.isEmpty {
                    Text("No parents")
                        .foregroundStyle(.tertiary)
                        .italic()
                        .font(.caption)
                } else {
                    ForEach(parents, id: \.self) { id in
                        HStack {
                            issueChipButton(id: id)
                            Spacer()
                            Button {
                                Task { await viewModel.removeParent(id) }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Remove parent")
                        }
                    }
                }

                IssueTypeahead(
                    placeholder: "Add parent by ID or title...",
                    availableIssues: viewModel.availableIssues,
                    excludeIDs: Set(issue.parents ?? []).union([issue.id]),
                    onSelect: { id in Task { await viewModel.addParent(id) } }
                )
            }

            // Children
            VStack(alignment: .leading, spacing: 4) {
                Text("Children")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                let children = issue.children ?? []
                if children.isEmpty {
                    Text("No children")
                        .foregroundStyle(.tertiary)
                        .italic()
                        .font(.caption)
                } else {
                    ForEach(children, id: \.self) { id in
                        HStack {
                            issueChipButton(id: id)
                            Spacer()
                            Button {
                                Task { await viewModel.removeChild(id) }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Remove child")
                        }
                    }
                }

                IssueTypeahead(
                    placeholder: "Add child by ID or title...",
                    availableIssues: viewModel.availableIssues,
                    excludeIDs: Set(issue.children ?? []).union([issue.id]),
                    onSelect: { id in Task { await viewModel.addChild(id) } }
                )
            }

            // Siblings (read-only, derived from shared parent)
            if let siblings = issue.siblings, !siblings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Siblings")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 4) {
                        ForEach(siblings, id: \.self) { id in
                            issueChipButton(id: id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func issueChipButton(id: String) -> some View {
        Button {
            onNavigateToIssue?(id)
        } label: {
            Text(id)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dependencies

    @ViewBuilder
    private func dependenciesSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dependencies")
                .font(.headline)

            if issue.deps.isEmpty {
                Text("No dependencies")
                    .foregroundStyle(.tertiary)
                    .italic()
                    .font(.callout)
            } else {
                ForEach(issue.deps, id: \.self) { depID in
                    HStack {
                        Text(depID)
                            .font(.system(.callout, design: .monospaced))

                        Spacer()

                        Button {
                            Task { await viewModel.removeDependency(from: depID) }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Remove dependency")
                    }
                    .padding(.vertical, 2)
                }
            }

            IssueTypeahead(
                placeholder: "Add dependency by ID or title...",
                availableIssues: viewModel.availableIssues,
                excludeIDs: Set(issue.deps).union([issue.id]),
                onSelect: { id in Task { await viewModel.addDependency(to: id) } }
            )
        }
    }

    // MARK: - Comments

    @ViewBuilder
    private func commentsSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comments")
                .font(.headline)

            let comments = issue.comments ?? []
            if comments.isEmpty {
                Text("No comments yet")
                    .foregroundStyle(.tertiary)
                    .italic()
                    .font(.callout)
            } else {
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(comment.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(comment.body)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack {
                TextField("Add a comment...", text: $newCommentText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        submitComment()
                    }

                Button("Send") {
                    submitComment()
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty)
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func submitComment() {
        let body = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return }
        Task { await viewModel.addComment(body: body) }
        newCommentText = ""
    }
}

// MARK: - TypeTextField

private struct TypeTextField: View {
    let currentType: String
    let onCommit: (String) -> Void

    @State private var text: String = ""
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            TextField("Type", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .focused($isFocused)
                .onSubmit {
                    let trimmed = text.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && trimmed != currentType {
                        onCommit(trimmed)
                    }
                    isEditing = false
                }
                .onAppear { isFocused = true }
        } else {
            Button {
                text = currentType
                isEditing = true
            } label: {
                TypeBadge(issueType: currentType)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (offsets, CGSize(width: maxX, height: y + rowHeight))
    }
}

#Preview {
    let vm = IssueDetailViewModel(client: PreviewData.client, project: PreviewData.project)

    IssueDetailView(viewModel: vm, issueID: "pv-a1b")
        .frame(width: 450, height: 700)
        .onAppear {
            vm.issue = PreviewData.sampleIssue
        }
}
