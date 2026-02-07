// PebbleVisionApp.swift
// PebbleVision
//
// Main app entry point. Configures the window, environment, and keyboard shortcuts.

import SwiftUI
import AppKit

@main
struct PebbleVisionApp: App {
    @State private var appState = AppState()
    @State private var projectStore = ProjectStore()
    @State private var pbClient = PBClient()

    init() {
        // When launched as a bare binary (not a .app bundle), macOS treats the
        // process as a background app. Windows appear but don't get proper key
        // window status — sheets can't accept keyboard input. This forces
        // macOS to treat us as a regular foreground application.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.layoutDirection, .leftToRight)
                .environment(appState)
                .environment(projectStore)
                .environment(pbClient)
                .frame(minWidth: 900, minHeight: 500)
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Issue...") {
                    appState.showCreateSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    appState.requestRefresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(\.layoutDirection, .leftToRight)
                .environment(projectStore)
                .environment(pbClient)
        }
    }
}
