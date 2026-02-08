// EventLogView.swift
// PebbleVision

import SwiftUI

struct EventLogView: View {
    @State private var viewModel: EventLogViewModel
    @State private var showSinceDate = false
    @State private var showUntilDate = false

    init(client: PBClient, project: Project) {
        _viewModel = State(initialValue: EventLogViewModel(client: client, project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter controls
            filterBar
            Divider()

            // Event list
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading events...")
                Spacer()
            } else if let error = viewModel.error {
                errorView(error)
            } else if viewModel.events.isEmpty {
                emptyState
            } else {
                List(viewModel.events) { event in
                    EventRowView(event: event)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 400)
        .task {
            await viewModel.fetchEvents()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await viewModel.fetchEvents()
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 16) {
            // Limit stepper
            Stepper("Limit: \(viewModel.limit)", value: $viewModel.limit, in: 10...500, step: 10)
                .frame(width: 160)

            Divider()
                .frame(height: 20)

            // Since date toggle + picker
            Toggle("Since:", isOn: $showSinceDate)
                .toggleStyle(.checkbox)
            if showSinceDate {
                DatePicker("", selection: Binding(
                    get: { viewModel.sinceDate ?? Date.distantPast },
                    set: { viewModel.sinceDate = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
                .frame(width: 120)
            }

            // Until date toggle + picker
            Toggle("Until:", isOn: $showUntilDate)
                .toggleStyle(.checkbox)
            if showUntilDate {
                DatePicker("", selection: Binding(
                    get: { viewModel.untilDate ?? Date() },
                    set: { viewModel.untilDate = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
                .frame(width: 120)
            }

            Spacer()

            Button {
                Task { await viewModel.fetchEvents() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onChange(of: showSinceDate) { _, newValue in
            if !newValue { viewModel.sinceDate = nil }
        }
        .onChange(of: showUntilDate) { _, newValue in
            if !newValue { viewModel.untilDate = nil }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No events found")
                .foregroundStyle(.secondary)
            Text("Adjust filters or check that the project has activity.")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
                Task { await viewModel.fetchEvents() }
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    let client = PBClient()
    let project = Project(name: "Preview", path: "/tmp", prefix: "pv")
    EventLogView(client: client, project: project)
        .frame(width: 700, height: 500)
}
