import Foundation
import Observation

/// Persists and manages the list of registered projects.
/// Uses UserDefaults with JSON encoding.
@Observable
final class ProjectStore: @unchecked Sendable {
    private static let storageKey = "pebbleVision.projects"

    /// All registered projects.
    private(set) var projects: [Project] = []

    /// Currently active project (selected in sidebar).
    var selectedProject: Project?

    init() {
        loadProjects()
    }

    /// Add a new project and persist.
    func addProject(_ project: Project) {
        projects.append(project)
        saveProjects()
    }

    /// Remove a project by its ID and persist.
    func removeProject(id: UUID) {
        projects.removeAll { $0.id == id }
        if selectedProject?.id == id {
            selectedProject = projects.first
        }
        saveProjects()
    }

    /// Update an existing project and persist.
    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            if selectedProject?.id == project.id {
                selectedProject = project
            }
            saveProjects()
        }
    }

    /// Validate that a path contains a `.pebbles/` directory.
    func validateProjectPath(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let pebblesPath = (path as NSString).appendingPathComponent(".pebbles")
        return FileManager.default.fileExists(atPath: pebblesPath, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    // MARK: - Persistence

    private func loadProjects() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            return
        }
        do {
            projects = try JSONDecoder().decode([Project].self, from: data)
        } catch {
            projects = []
        }
    }

    private func saveProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            // Silently fail — persistence is best-effort
        }
    }
}
