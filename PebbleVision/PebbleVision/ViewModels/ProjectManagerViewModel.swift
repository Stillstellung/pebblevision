// ProjectManagerViewModel.swift
// PebbleVision
//
// Manages project lifecycle: init, import, add/remove projects.

import Foundation

@Observable
final class ProjectManagerViewModel {
    var isInitializing = false
    var isImporting = false
    var error: PBError?

    private let pbClient: PBClient
    private let projectStore: ProjectStore

    init(pbClient: PBClient, projectStore: ProjectStore) {
        self.pbClient = pbClient
        self.projectStore = projectStore
    }

    /// Initialize a new pebbles project at the given path.
    func initProject(at path: String, prefix: String? = nil) async {
        isInitializing = true
        error = nil
        do {
            try await pbClient.initProject(at: path, prefix: prefix)
            let name = (path as NSString).lastPathComponent
            let project = Project(
                name: name,
                path: path,
                prefix: prefix ?? name.lowercased(),
                lastOpened: Date()
            )
            projectStore.addProject(project)
            projectStore.selectedProject = project
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isInitializing = false
    }

    /// Import beads into an existing pebbles project.
    func importBeads(at path: String, from source: String, backup: Bool = true) async {
        isImporting = true
        error = nil
        do {
            try await pbClient.importBeads(at: path, from: source, backup: backup)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isImporting = false
    }

    /// Add an existing project by validating it has a .pebbles/ directory.
    func addExistingProject(path: String) async {
        error = nil

        guard projectStore.validateProjectPath(path) else {
            error = .notInitialized(path: path)
            return
        }

        // Read prefix from .pebbles/config.json
        let configPath = (path as NSString).appendingPathComponent(".pebbles/config.json")
        var prefix = (path as NSString).lastPathComponent.lowercased()

        if let data = FileManager.default.contents(atPath: configPath),
           let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let configPrefix = config["prefix"] as? String {
            prefix = configPrefix
        }

        let name = (path as NSString).lastPathComponent
        let project = Project(
            name: name,
            path: path,
            prefix: prefix,
            lastOpened: Date()
        )
        projectStore.addProject(project)
        projectStore.selectedProject = project
    }

    /// Remove a project from the store (does not delete files).
    func removeProject(id: UUID) {
        projectStore.removeProject(id: id)
    }
}
