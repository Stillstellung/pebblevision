# PebbleVision Architecture

> A native macOS SwiftUI app providing a GUI for the [pebbles](https://github.com/Martian-Engineering/pebbles) issue tracker CLI (`pb`).

## 1. Platform & Tooling

| Decision | Value |
|---|---|
| Framework | SwiftUI |
| Minimum OS | macOS 14.0 (Sonoma) |
| Swift version | 5.9+ |
| Build system | Xcode 15+ / Swift Package Manager |
| CLI integration | `Foundation.Process` shelling out to `pb` |
| Architecture | MVVM + Services |

---

## 2. Project Structure

```
PebbleVision/
├── PebbleVision.xcodeproj
├── PebbleVision/
│   ├── App/
│   │   ├── PebbleVisionApp.swift              # @main entry point, WindowGroup, environment setup
│   │   └── AppState.swift                     # Global observable app state (selected project, errors)
│   │
│   ├── Models/
│   │   ├── Issue.swift                        # Issue struct (Codable, Identifiable, Hashable)
│   │   ├── IssueComment.swift                 # Comment struct
│   │   ├── Event.swift                        # Event log entry struct (Codable)
│   │   ├── Dependency.swift                   # DepNode tree struct
│   │   ├── Project.swift                      # Project bookmark (path, prefix, display name)
│   │   └── PBTypes.swift                      # Enums: IssueStatus, IssueType, Priority, EventType
│   │
│   ├── Services/
│   │   ├── PBClient.swift                     # Core async wrapper around `pb` CLI
│   │   ├── PBOutputParser.swift               # Parse text output from list, show, dep tree, ready
│   │   ├── PBJSONParser.swift                 # Parse --json output from log, list --json, show --json
│   │   └── ProjectStore.swift                 # Persist project bookmarks (UserDefaults/plist)
│   │
│   ├── ViewModels/
│   │   ├── IssueListViewModel.swift           # Drives IssueListView: fetch, filter, sort, refresh
│   │   ├── IssueDetailViewModel.swift         # Drives IssueDetailView: show, update, comment, close
│   │   ├── IssueCreateViewModel.swift         # Drives create sheet: validation, submit
│   │   ├── DependencyTreeViewModel.swift      # Drives dep tree: fetch, flatten for outline
│   │   ├── EventLogViewModel.swift            # Drives log view: fetch, filter by date, pagination
│   │   ├── ReadyViewModel.swift               # Drives ready view: fetch unblocked issues
│   │   └── ProjectManagerViewModel.swift      # Project CRUD, init, import, prefix management
│   │
│   ├── Views/
│   │   ├── Sidebar/
│   │   │   ├── SidebarView.swift              # Project selector + navigation links
│   │   │   └── ProjectSelectorView.swift      # Dropdown/list of registered projects
│   │   │
│   │   ├── Issues/
│   │   │   ├── IssueListView.swift            # Filterable table/list of issues
│   │   │   ├── IssueRowView.swift             # Single row in issue list
│   │   │   ├── IssueDetailView.swift          # Full issue detail panel
│   │   │   ├── IssueCreateSheet.swift         # Modal sheet for creating issues
│   │   │   ├── IssueEditSheet.swift           # Modal sheet for editing issue fields
│   │   │   └── IssueFilterBar.swift           # Status/type/priority filter controls
│   │   │
│   │   ├── Dependencies/
│   │   │   ├── DependencyTreeView.swift       # Recursive outline of dep tree
│   │   │   └── DepNodeRowView.swift           # Single node in tree with status badge
│   │   │
│   │   ├── EventLog/
│   │   │   ├── EventLogView.swift             # Scrollable event log with date filters
│   │   │   └── EventRowView.swift             # Single event entry
│   │   │
│   │   ├── Ready/
│   │   │   └── ReadyView.swift                # Issues with no open blockers
│   │   │
│   │   ├── Settings/
│   │   │   └── SettingsView.swift             # pb path config, project management, preferences
│   │   │
│   │   └── Shared/
│   │       ├── StatusBadge.swift              # Colored status pill (open/in_progress/closed)
│   │       ├── PriorityBadge.swift            # P0-P4 colored indicator
│   │       ├── TypeBadge.swift                # Issue type chip (task/epic/bug)
│   │       ├── LoadingOverlay.swift           # Spinner overlay for async operations
│   │       ├── ErrorBanner.swift              # Dismissible error banner
│   │       └── EmptyStateView.swift           # "No issues" / "No results" placeholder
│   │
│   ├── Utilities/
│   │   ├── ProcessRunner.swift                # Low-level async Process execution
│   │   └── DateFormatting.swift               # Shared date formatters (RFC3339, display)
│   │
│   ├── Resources/
│   │   └── Assets.xcassets                    # App icon, accent color
│   │
│   └── Preview Content/
│       └── PreviewData.swift                  # Sample data for SwiftUI previews
│
├── PebbleVisionTests/
│   ├── PBOutputParserTests.swift              # Unit tests for text parsing
│   ├── PBJSONParserTests.swift                # Unit tests for JSON parsing
│   ├── ModelTests.swift                       # Model encoding/decoding tests
│   └── ViewModelTests.swift                   # ViewModel logic tests (with mock PBClient)
│
├── ARCHITECTURE.md                            # This file
└── README.md                                  # (if needed)
```

---

## 3. Data Models

### 3.1 Core Enums (`PBTypes.swift`)

```swift
/// Issue lifecycle status
enum IssueStatus: String, Codable, CaseIterable {
    case open
    case inProgress = "in_progress"
    case closed

    var displayName: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In Progress"
        case .closed: "Closed"
        }
    }
}

/// Issue classification
enum IssueType: String, Codable, CaseIterable {
    case task
    case epic
    case bug
}

/// Severity level P0 (critical) through P4 (trivial)
enum Priority: Int, Codable, CaseIterable, Comparable {
    case p0 = 0, p1 = 1, p2 = 2, p3 = 3, p4 = 4

    var label: String { "P\(rawValue)" }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Event types from the pebbles event log
enum EventType: String, Codable {
    case create
    case titleUpdated = "title_updated"
    case statusUpdate = "status_update"
    case update
    case close
    case comment
    case rename
    case depAdd = "dep_add"
    case depRm = "dep_rm"
}
```

### 3.2 Issue (`Issue.swift`)

```swift
/// Represents a pebbles issue. Parsed from `pb list` or `pb show` text output,
/// or from `pb list --json` / `pb show --json` JSON output.
struct Issue: Identifiable, Hashable, Codable {
    var id: String           // e.g. "pv-a1b2c3"
    var title: String
    var description: String
    var issueType: IssueType
    var status: IssueStatus
    var priority: Priority
    var createdAt: Date?
    var updatedAt: Date?
    var closedAt: Date?

    // Populated from `pb show --json` detail response
    var parents: [String]?       // Parent issue IDs
    var children: [String]?      // Child issue IDs
    var siblings: [String]?      // Sibling issue IDs
    var deps: [String]           // Dependency issue IDs (always array, never null)
    var comments: [IssueComment]?
}
```

### 3.3 IssueComment (`IssueComment.swift`)

```swift
struct IssueComment: Identifiable, Hashable, Codable {
    var id: String { "\(issueID)-\(timestamp)" }
    var issueID: String
    var body: String
    var timestamp: Date
}
```

### 3.4 Event (`Event.swift`)

Matches the `events.jsonl` structure from pebbles:

```swift
/// A single entry from `pb log --json`. Each event is a JSON line.
struct Event: Identifiable, Codable {
    var id: String { "\(issueID)-\(timestamp)-\(type)" }
    var type: EventType
    var timestamp: Date
    var issueID: String
    var payload: [String: String]

    // Populated from log pretty-print or git blame
    var actor: String?
    var actorDate: String?
    var title: String?

    enum CodingKeys: String, CodingKey {
        case type, timestamp, issueID = "issue_id", payload
    }
}
```

### 3.5 Dependency Tree (`Dependency.swift`)

```swift
/// Recursive tree node mirroring pebbles DepNode.
/// Used by `pb dep tree ISSUE-ID`.
struct DepNode: Identifiable {
    var id: String { issue.id }
    var issue: Issue
    var dependencies: [DepNode]
}
```

### 3.6 Project (`Project.swift`)

```swift
/// A registered project (repo) that pebbleVision can manage.
struct Project: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String              // Display name (e.g. "pebbleVision")
    var path: String              // Absolute path to repo root containing .pebbles/
    var prefix: String            // Issue ID prefix (e.g. "pv")
    var lastOpened: Date?
}
```

---

## 4. Service Layer

### 4.1 ProcessRunner (`Utilities/ProcessRunner.swift`)

Low-level async wrapper around `Foundation.Process`:

```swift
actor ProcessRunner {
    struct Output {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    /// Execute a CLI command asynchronously.
    /// - Parameters:
    ///   - executable: Path to the executable (e.g. "/usr/local/bin/pb")
    ///   - arguments: Command arguments
    ///   - workingDirectory: The repo directory to run in
    ///   - environment: Extra env vars (always includes NO_COLOR=1)
    func run(
        executable: String,
        arguments: [String],
        workingDirectory: String,
        environment: [String: String] = [:]
    ) async throws -> Output
}
```

**Implementation details:**
- Uses `Process` with `Pipe` for stdout/stderr capture
- Sets `NO_COLOR=1` and `PB_NO_COLOR=1` in environment (disable ANSI)
- Sets `TERM=dumb` to prevent pager activation
- Runs on a detached `Task` to avoid blocking the main actor
- Throws `PBError` on non-zero exit codes
- Timeout after 30 seconds (configurable)

### 4.2 PBClient (`Services/PBClient.swift`)

High-level async API wrapping every `pb` command. Each method calls `ProcessRunner`, then routes output through the appropriate parser.

```swift
@Observable
final class PBClient {
    private let runner = ProcessRunner()
    private let textParser = PBOutputParser()
    private let jsonParser = PBJSONParser()

    /// User-configurable path to pb binary. Defaults to "pb" (found via PATH).
    var pbPath: String = "pb"

    // MARK: - Project Setup

    func initProject(at path: String, prefix: String?) async throws
    func importBeads(at path: String, from sourcePath: String, backup: Bool) async throws

    // MARK: - Issue CRUD

    /// Returns the new issue ID string
    func createIssue(
        in project: Project,
        title: String,
        type: IssueType?,
        priority: Priority?,
        description: String?
    ) async throws -> String

    func listIssues(
        in project: Project,
        status: Set<IssueStatus>?,
        type: IssueType?,
        priority: Priority?,
        stale: Bool,
        staleDays: Int?
    ) async throws -> [Issue]

    func showIssue(
        in project: Project,
        issueID: String
    ) async throws -> Issue  // Full detail including comments, hierarchy

    func updateIssue(
        in project: Project,
        issueID: String,
        status: IssueStatus?,
        type: IssueType?,
        priority: Priority?,
        description: String?,
        parent: String?
    ) async throws

    func closeIssue(in project: Project, issueID: String) async throws

    // MARK: - Comments

    func addComment(in project: Project, issueID: String, body: String) async throws

    // MARK: - Dependencies

    func addDependency(
        in project: Project,
        from issueA: String,
        to issueB: String,
        type: String?  // "parent-child" or nil for default "blocks"
    ) async throws

    func removeDependency(in project: Project, from issueA: String, to issueB: String) async throws

    func dependencyTree(in project: Project, issueID: String) async throws -> DepNode

    // MARK: - Queries

    func readyIssues(in project: Project) async throws -> [Issue]

    func eventLog(
        in project: Project,
        limit: Int?,
        since: Date?,
        until: Date?,
        noGit: Bool
    ) async throws -> [Event]

    // MARK: - ID Management

    func renameIssue(in project: Project, oldID: String, newID: String) async throws
    func renamePrefix(in project: Project, prefix: String, scope: RenamePrefixScope) async throws

    // MARK: - Meta

    func version() async throws -> String
}

enum RenamePrefixScope {
    case open   // --open
    case full   // --full
}
```

**Command construction pattern** (example for `listIssues`):

```swift
func listIssues(in project: Project, ...) async throws -> [Issue] {
    var args = ["list", "--json"]
    if let status { args += ["--status", status.map(\.rawValue).joined(separator: ",")] }
    if let type { args += ["--type", type.rawValue] }
    if let priority { args += ["--priority", priority.label] }
    if stale { args.append("--stale") }
    if let staleDays { args += ["--stale-days", "\(staleDays)"] }

    let output = try await runner.run(
        executable: pbPath,
        arguments: args,
        workingDirectory: project.path
    )
    return try jsonParser.parseIssueList(output.stdout)
}
```

**Strategy for choosing output format:**
| Command | Output format | Rationale |
|---|---|---|
| `pb list` | `--json` | Structured; avoids fragile text parsing |
| `pb show` | `--json` | Structured; includes hierarchy + comments |
| `pb log` | `--json` | JSON lines; each line is a complete Event |
| `pb ready` | `--json` | Same structured format as list |
| `pb dep tree` | Text (parsed) | No `--json` flag available for dep tree |
| `pb create` | Text (parsed) | Returns just the new issue ID on stdout |
| `pb version` | Text | Single line |
| Mutations | Exit code | stdout ignored; non-zero = error from stderr |

### 4.3 PBOutputParser (`Services/PBOutputParser.swift`)

Parses text output for commands that lack `--json` support:

```swift
struct PBOutputParser {
    /// Parse `pb create` output to extract the new issue ID.
    /// Expected: "Created pb-abc123\n" or similar single-line output.
    func parseCreateOutput(_ text: String) -> String

    /// Parse `pb dep tree` text output into a DepNode tree.
    /// Output uses indentation to indicate depth:
    ///   ○ pb-abc [● P2] [task] - Title
    ///     ○ pb-def [● P1] [bug] - Child Title
    ///       ○ pb-ghi [● P3] [task] - Grandchild
    func parseDepTree(_ text: String) -> DepNode?

    /// Parse a single issue line from list/tree output.
    /// Format: "○ pb-abc [● P2] [task] - Title"
    /// Status indicator: ○ = open, ◑ = in_progress, ● = closed
    func parseIssueLine(_ line: String) -> Issue?

    /// Parse `pb version` output.
    func parseVersion(_ text: String) -> String
}
```

### 4.4 PBJSONParser (`Services/PBJSONParser.swift`)

Parses JSON output:

```swift
struct PBJSONParser {
    private let decoder: JSONDecoder  // configured with date strategy

    /// Parse `pb list --json` output. Returns array of Issue.
    /// JSON shape per item: {"id", "title", "description", "type", "status", "priority", "created_at", "updated_at", "closed_at", "deps"}
    func parseIssueList(_ json: String) throws -> [Issue]

    /// Parse `pb show --json` output. Returns Issue with full detail.
    /// JSON shape: { ...issueFields, "parents", "siblings", "children", "comments": [{"body", "timestamp"}] }
    func parseIssueDetail(_ json: String) throws -> Issue

    /// Parse `pb log --json` output. Each line is a JSON object.
    /// JSON shape per line: {"type", "timestamp", "issue_id", "payload": {"key": "value"}}
    func parseEventLog(_ jsonLines: String) throws -> [Event]

    /// Parse `pb ready --json` output. Same shape as list.
    func parseReadyList(_ json: String) throws -> [Issue]
}
```

**JSON field mapping** (from `json_output.go` in pebbles source):

```
issueJSON {
    id:          string    // "pb-abc123"
    title:       string
    description: string
    type:        string    // "task", "epic", "bug"
    status:      string    // "open", "in_progress", "closed"
    priority:    string    // "P0" through "P4" (label form, not int)
    created_at:  string    // RFC3339
    updated_at:  string    // RFC3339
    closed_at:   string    // RFC3339 or ""
    deps:        [string]  // always array, never null
}

issueDetailJSON extends issueJSON {
    parents:  [string]     // issue IDs
    siblings: [string]     // issue IDs
    children: [string]     // issue IDs
    comments: [{
        body:      string
        timestamp: string  // RFC3339
    }]
}

Event (log --json, one per line) {
    type:      string              // "create", "status_update", etc.
    timestamp: string              // RFC3339
    issue_id:  string
    payload:   {string: string}    // varies by event type
}
```

### 4.5 ProjectStore (`Services/ProjectStore.swift`)

```swift
@Observable
final class ProjectStore {
    /// All registered projects. Persisted to UserDefaults.
    private(set) var projects: [Project]

    /// Currently active project (selected in sidebar).
    var selectedProject: Project?

    func addProject(_ project: Project)
    func removeProject(id: UUID)
    func updateProject(_ project: Project)

    /// Validate that a path contains `.pebbles/` directory.
    func validateProjectPath(_ path: String) -> Bool
}
```

Persistence: `UserDefaults.standard` with key `"pebbleVision.projects"`, encoded as JSON via `Codable`.

---

## 5. ViewModels

All ViewModels are `@Observable` classes. They hold loading/error state and call `PBClient` methods.

### 5.1 Common Pattern

```swift
@Observable
final class SomeViewModel {
    var items: [Item] = []
    var isLoading = false
    var error: PBError?

    private let client: PBClient
    private let project: Project

    func fetch() async {
        isLoading = true
        error = nil
        do {
            items = try await client.someMethod(in: project)
        } catch let err as PBError {
            error = err
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
        isLoading = false
    }
}
```

### 5.2 IssueListViewModel

```swift
@Observable
final class IssueListViewModel {
    var issues: [Issue] = []
    var isLoading = false
    var error: PBError?

    // Filter state (bound to IssueFilterBar)
    var statusFilter: Set<IssueStatus> = [.open, .inProgress]
    var typeFilter: IssueType?
    var priorityFilter: Priority?
    var showStale = false
    var searchText = ""

    // Computed
    var filteredIssues: [Issue]  // applies searchText on top of server filters

    func fetchIssues() async      // calls client.listIssues with current filters
    func refreshAfterMutation() async  // re-fetches with same filters
}
```

### 5.3 IssueDetailViewModel

```swift
@Observable
final class IssueDetailViewModel {
    var issue: Issue?
    var isLoading = false
    var error: PBError?
    var isSaving = false

    func fetchIssue(id: String) async
    func updateStatus(_ status: IssueStatus) async
    func updatePriority(_ priority: Priority) async
    func updateType(_ type: IssueType) async
    func updateDescription(_ description: String) async
    func setParent(_ parentID: String) async
    func closeIssue() async
    func addComment(body: String) async
    func addDependency(to targetID: String, type: String?) async
    func removeDependency(from targetID: String) async
}
```

Each mutation method: sets `isSaving = true`, calls `PBClient`, then calls `fetchIssue()` to refresh state, then sets `isSaving = false`.

### 5.4 IssueCreateViewModel

```swift
@Observable
final class IssueCreateViewModel {
    // Form fields
    var title = ""
    var description = ""
    var issueType: IssueType = .task
    var priority: Priority = .p2

    var isSubmitting = false
    var error: PBError?
    var createdIssueID: String?

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    func submit() async -> String?  // returns new issue ID on success
    func reset()                     // clear form for next create
}
```

### 5.5 DependencyTreeViewModel

```swift
@Observable
final class DependencyTreeViewModel {
    var rootNode: DepNode?
    var isLoading = false
    var error: PBError?
    var selectedIssueID: String = ""  // input field for which issue to show tree

    func fetchTree(for issueID: String) async
}
```

### 5.6 EventLogViewModel

```swift
@Observable
final class EventLogViewModel {
    var events: [Event] = []
    var isLoading = false
    var error: PBError?

    var limit: Int = 50
    var sinceDate: Date?
    var untilDate: Date?

    func fetchEvents() async  // calls client.eventLog with --json
}
```

### 5.7 ReadyViewModel

```swift
@Observable
final class ReadyViewModel {
    var readyIssues: [Issue] = []
    var isLoading = false
    var error: PBError?

    func fetchReady() async
}
```

### 5.8 ProjectManagerViewModel

```swift
@Observable
final class ProjectManagerViewModel {
    var isInitializing = false
    var isImporting = false
    var error: PBError?

    func initProject(at path: String, prefix: String?) async
    func importBeads(at path: String, from source: String, backup: Bool) async
    func addExistingProject(path: String) async  // validates .pebbles/ exists, reads config
    func removeProject(id: UUID)
}
```

---

## 6. Error Handling

```swift
/// Unified error type for PebbleVision.
enum PBError: LocalizedError {
    case notInitialized(path: String)       // no .pebbles/ in directory
    case issueNotFound(id: String)          // pb show returned error
    case commandFailed(stderr: String, exitCode: Int32)  // non-zero exit
    case parseError(detail: String)         // output didn't match expected format
    case pbNotFound(path: String)           // pb binary not at configured path
    case timeout                            // process exceeded time limit
    case unexpected(String)                 // catch-all

    var errorDescription: String? { ... }
}
```

---

## 7. UI Layout

### 7.1 Window Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  Toolbar: [Refresh] [+ New Issue]              [Search Field]   │
├──────────────┬──────────────────────────┬───────────────────────┤
│  Sidebar     │  Main Content            │  Detail Panel         │
│              │                          │  (Inspector)          │
│  Project ▾   │  ┌────────────────────┐  │                       │
│  ─────────   │  │ Filter Bar         │  │  Issue Title          │
│  ● Issues    │  │ Status|Type|Priority│  │  Status ▾  Priority ▾│
│  ○ Ready     │  ├────────────────────┤  │  Type: task           │
│  ○ Dep Tree  │  │ Issue Row          │  │  ──────────────       │
│  ○ Event Log │  │ Issue Row          │  │  Description          │
│  ─────────   │  │ Issue Row (sel.)   │  │  ──────────────       │
│  ⚙ Settings  │  │ Issue Row          │  │  Dependencies         │
│              │  │ ...                │  │  ──────────────       │
│              │  └────────────────────┘  │  Comments             │
│              │                          │  [+ Add Comment]      │
├──────────────┴──────────────────────────┴───────────────────────┤
│  Status Bar: "42 issues · Last refreshed 10s ago"     [pb v0.x] │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 NavigationSplitView Layout

```swift
// PebbleVisionApp.swift
@main
struct PebbleVisionApp: App {
    @State private var appState = AppState()
    @State private var projectStore = ProjectStore()
    @State private var pbClient = PBClient()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(projectStore)
                .environment(pbClient)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Issue...") { appState.showCreateSheet = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button("Refresh") { appState.requestRefresh() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(projectStore)
                .environment(pbClient)
        }
    }
}
```

```swift
// ContentView wraps the three-column NavigationSplitView
struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            // Switches based on appState.selectedSection
            switch appState.selectedSection {
            case .issues:   IssueListView()
            case .ready:    ReadyView()
            case .depTree:  DependencyTreeView()
            case .eventLog: EventLogView()
            }
        } detail: {
            if let issueID = appState.selectedIssueID {
                IssueDetailView(issueID: issueID)
            } else {
                EmptyStateView(message: "Select an issue")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $appState.showCreateSheet) {
            IssueCreateSheet()
        }
    }
}
```

### 7.3 AppState

```swift
/// Global navigation and UI state.
@Observable
final class AppState {
    enum Section: String, CaseIterable {
        case issues = "Issues"
        case ready = "Ready"
        case depTree = "Dependencies"
        case eventLog = "Event Log"
    }

    var selectedSection: Section = .issues
    var selectedIssueID: String?
    var showCreateSheet = false
    var lastRefresh: Date?
    var globalError: PBError?

    /// Triggers a Notification that ViewModels observe.
    func requestRefresh() {
        NotificationCenter.default.post(name: .pbRefreshRequested, object: nil)
        lastRefresh = Date()
    }
}

extension Notification.Name {
    static let pbRefreshRequested = Notification.Name("pbRefreshRequested")
}
```

---

## 8. Key Views Detail

### 8.1 SidebarView

- **ProjectSelectorView**: Picker/Menu at top of sidebar showing `projectStore.projects`. Selecting a project sets `projectStore.selectedProject`. "Add Project..." option opens folder picker + validates `.pebbles/` exists. "Init New Project..." runs `pb init`.
- **Navigation section**: `List` with `NavigationLink` for each `AppState.Section`.
- **Settings link**: At bottom of sidebar.

### 8.2 IssueListView

- **IssueFilterBar**: Horizontal row of `Picker` controls for status (multi-select via toggles), type, priority. A toggle for "Show Stale".
- **List body**: `List(viewModel.filteredIssues)` rendering `IssueRowView` for each.
- **IssueRowView**: Horizontal layout: `StatusBadge` + issue ID (monospaced, dimmed) + title + `PriorityBadge` + `TypeBadge`.
- **Selection**: Setting `appState.selectedIssueID` on tap, which drives the detail column.
- **Toolbar**: Refresh button, New Issue button (opens sheet), search field.

### 8.3 IssueDetailView

Scrollable detail panel showing:
1. **Header**: Title (editable on double-click or edit button), ID (copyable).
2. **Metadata row**: Status picker, Priority picker, Type picker — each triggers `viewModel.updateX()` on change.
3. **Description**: Editable text area with save button.
4. **Hierarchy section**: Parents, Children, Siblings as clickable chips that navigate to that issue.
5. **Dependencies section**: List of deps with status badges. "Add Dependency" button with issue ID text field.
6. **Comments section**: Chronological list. "Add Comment" text field + submit button at bottom.
7. **Actions**: Close Issue button (with confirmation alert), Rename button.

### 8.4 IssueCreateSheet

Modal `.sheet` with form:
- Title (required, TextField)
- Type (Picker: task/epic/bug)
- Priority (Picker: P0-P4, default P2)
- Description (optional, TextEditor)
- Cancel / Create buttons
- Disabled Create button when title is empty
- On success: dismiss sheet, refresh issue list, optionally select new issue

### 8.5 DependencyTreeView

- Text field to enter an issue ID (with autocomplete from known issues).
- "Show Tree" button.
- `OutlineGroup` or recursive `DisclosureGroup` rendering `DepNodeRowView` for each node.
- Each node shows: status indicator, issue ID, priority badge, title.
- Tapping a node navigates to its detail.

### 8.6 EventLogView

- Date range pickers (Since / Until) and limit stepper.
- Scrollable `List` of `EventRowView`.
- Each row: timestamp, event type badge (colored), issue ID (clickable), actor name, detail summary.
- Newest events first (default from pb log).

### 8.7 ReadyView

- Simple list of issues returned by `pb ready`.
- Same `IssueRowView` rendering as IssueListView.
- Tapping an issue navigates to detail.

### 8.8 SettingsView

macOS Settings window with tabs:
- **General**: Path to `pb` binary (text field + file picker), default project.
- **Projects**: List of registered projects with Add/Remove. Edit prefix per project.
- **About**: App version, pb version (fetched), link to pebbles repo.

---

## 9. Data Flow

### 9.1 Refresh After Mutations

Every mutation (create, update, close, comment, add dep, etc.) follows this pattern:

```
User action → ViewModel mutation method → PBClient.command() → pb CLI
    → on success: ViewModel.fetch() to reload current view
    → on error: ViewModel.error = PBError (shown via ErrorBanner)
```

The `IssueDetailViewModel` refreshes itself. The `IssueListViewModel` refreshes via `NotificationCenter` (`.pbRefreshRequested`), or the detail view can call a refresh closure passed from the list.

### 9.2 Loading States

```
View observes viewModel.isLoading:
  - true  → show LoadingOverlay (ProgressView overlay with dimmed background)
  - false → show content or empty state

View observes viewModel.isSaving (for mutations):
  - true  → disable controls, show inline spinner
  - false → re-enable controls
```

### 9.3 Error Display

```
viewModel.error != nil → ErrorBanner at top of view
  - Shows error message
  - Dismiss button (sets error = nil)
  - Retry button (calls fetch again)
```

### 9.4 Project Switching

```
User selects project in ProjectSelectorView
  → projectStore.selectedProject changes
  → ContentView recreates child views (new ViewModel instances)
  → Each ViewModel.fetch() fires in .task { } on appear
```

---

## 10. Complete File List

| # | File | Description |
|---|---|---|
| 1 | `App/PebbleVisionApp.swift` | @main entry, WindowGroup, Scene, Commands, environment injection |
| 2 | `App/AppState.swift` | Global nav state: selected section, selected issue, sheet presentation, refresh |
| 3 | `Models/Issue.swift` | Issue struct: Identifiable, Codable, all fields from pb JSON |
| 4 | `Models/IssueComment.swift` | IssueComment struct with body and timestamp |
| 5 | `Models/Event.swift` | Event struct matching pb log --json output |
| 6 | `Models/Dependency.swift` | DepNode recursive tree struct |
| 7 | `Models/Project.swift` | Project bookmark: path, name, prefix, id |
| 8 | `Models/PBTypes.swift` | Enums: IssueStatus, IssueType, Priority, EventType |
| 9 | `Services/PBClient.swift` | Async pb CLI wrapper, all commands, argument construction |
| 10 | `Services/PBOutputParser.swift` | Text output parsing: create result, dep tree, issue lines, version |
| 11 | `Services/PBJSONParser.swift` | JSON parsing: issue list, issue detail, event log, ready list |
| 12 | `Services/ProjectStore.swift` | Project persistence via UserDefaults, selection management |
| 13 | `ViewModels/IssueListViewModel.swift` | List fetch, filter state, search, refresh |
| 14 | `ViewModels/IssueDetailViewModel.swift` | Show, update, comment, close, dependency management |
| 15 | `ViewModels/IssueCreateViewModel.swift` | Form state, validation, submit |
| 16 | `ViewModels/DependencyTreeViewModel.swift` | Fetch and hold dep tree |
| 17 | `ViewModels/EventLogViewModel.swift` | Log fetch with date range and limit |
| 18 | `ViewModels/ReadyViewModel.swift` | Ready issues fetch |
| 19 | `ViewModels/ProjectManagerViewModel.swift` | Init, import, add/remove projects |
| 20 | `Views/Sidebar/SidebarView.swift` | Project selector + section navigation |
| 21 | `Views/Sidebar/ProjectSelectorView.swift` | Project picker dropdown with add/init actions |
| 22 | `Views/Issues/IssueListView.swift` | Filtered issue list with toolbar |
| 23 | `Views/Issues/IssueRowView.swift` | Single issue row: badges + ID + title |
| 24 | `Views/Issues/IssueDetailView.swift` | Full detail panel: metadata, description, deps, comments |
| 25 | `Views/Issues/IssueCreateSheet.swift` | Modal create form |
| 26 | `Views/Issues/IssueEditSheet.swift` | Modal edit form for title/description |
| 27 | `Views/Issues/IssueFilterBar.swift` | Status/type/priority filter controls |
| 28 | `Views/Dependencies/DependencyTreeView.swift` | Issue ID input + recursive tree display |
| 29 | `Views/Dependencies/DepNodeRowView.swift` | Single tree node with badges |
| 30 | `Views/EventLog/EventLogView.swift` | Date-filtered event log list |
| 31 | `Views/EventLog/EventRowView.swift` | Single event: type badge, issue link, details |
| 32 | `Views/Ready/ReadyView.swift` | Unblocked issues list |
| 33 | `Views/Settings/SettingsView.swift` | Settings tabs: General, Projects, About |
| 34 | `Views/Shared/StatusBadge.swift` | Colored pill for issue status |
| 35 | `Views/Shared/PriorityBadge.swift` | P0-P4 colored indicator |
| 36 | `Views/Shared/TypeBadge.swift` | Issue type chip |
| 37 | `Views/Shared/LoadingOverlay.swift` | ProgressView overlay |
| 38 | `Views/Shared/ErrorBanner.swift` | Dismissible error message with retry |
| 39 | `Views/Shared/EmptyStateView.swift` | Placeholder for empty states |
| 40 | `Utilities/ProcessRunner.swift` | Async Process execution actor |
| 41 | `Utilities/DateFormatting.swift` | RFC3339 and display date formatters |
| 42 | `Resources/Assets.xcassets` | App icon and accent color |
| 43 | `Preview Content/PreviewData.swift` | Sample Issues, Events, Projects for previews |

**Tests:**

| # | File | Description |
|---|---|---|
| T1 | `PBOutputParserTests.swift` | Test text parsing for create, dep tree, issue lines |
| T2 | `PBJSONParserTests.swift` | Test JSON parsing for list, show, log output |
| T3 | `ModelTests.swift` | Test Codable encoding/decoding for all models |
| T4 | `ViewModelTests.swift` | Test ViewModel logic with mocked PBClient |

---

## 11. Worker Decomposition

### Worker A: Models + PBClient + Parsers

**Files:** #3-12, #40-41, T1-T3 (Models/, Services/, Utilities/)

**Scope:**
- All model structs and enums (Issue, Event, IssueComment, DepNode, Project, PBTypes)
- `ProcessRunner` actor (async Process wrapper)
- `PBClient` with all method signatures and implementations
- `PBOutputParser` — text parsing for create output, dep tree, issue lines, version
- `PBJSONParser` — JSON parsing for list, show, log, ready
- `ProjectStore` — UserDefaults persistence
- `DateFormatting` utility
- Unit tests for parsers and models

**Dependencies:** None. This is the foundation layer.

**Deliverables:**
- All files compile independently (no View or ViewModel imports)
- Parser tests pass with hardcoded sample output matching real `pb` formats
- Mock-friendly: `PBClient` can be subclassed or protocol-extracted for testing

**Test data to include in `PreviewData.swift`:** Sample JSON strings matching `pb list --json`, `pb show --json`, and `pb log --json` output. Sample text matching `pb dep tree` and `pb create` output.

---

### Worker B: Core Views (Issues)

**Files:** #13-15, #22-27, #34-39, #43 (Issue ViewModels, Issue Views, Shared views, PreviewData)

**Scope:**
- `IssueListViewModel`, `IssueDetailViewModel`, `IssueCreateViewModel`
- `IssueListView`, `IssueRowView`, `IssueDetailView`, `IssueCreateSheet`, `IssueEditSheet`, `IssueFilterBar`
- All shared badge views: `StatusBadge`, `PriorityBadge`, `TypeBadge`
- `LoadingOverlay`, `ErrorBanner`, `EmptyStateView`
- `PreviewData.swift` with sample model instances

**Dependencies:** Worker A (models and PBClient types). Worker B can start immediately using the model structs from the architecture doc, and integrate Worker A's actual files at merge time.

**Deliverables:**
- All views render correctly in SwiftUI previews using `PreviewData`
- Filter bar controls update ViewModel state
- Issue selection updates `appState.selectedIssueID`
- Create sheet validates input and calls PBClient (can use stub until merge)
- Detail view shows all sections: metadata, description, hierarchy, deps, comments

---

### Worker C: Advanced Views (Dep Tree, Event Log, Ready, Settings)

**Files:** #16-18, #28-33 (Advanced ViewModels and Views)

**Scope:**
- `DependencyTreeViewModel`, `EventLogViewModel`, `ReadyViewModel`
- `DependencyTreeView`, `DepNodeRowView`
- `EventLogView`, `EventRowView`
- `ReadyView`
- `SettingsView`

**Dependencies:** Worker A (models). Can stub PBClient calls like Worker B.

**Deliverables:**
- Dep tree renders recursively using `OutlineGroup` or `DisclosureGroup`
- Event log displays with date filtering
- Ready view shows unblocked issues
- Settings view configures pb path and manages projects

---

### Worker D: App Shell, Navigation, Project Management, Xcode Project

**Files:** #1-2, #19-21, Xcode project setup

**Scope:**
- `PebbleVisionApp.swift` — @main, WindowGroup, Settings scene, Commands
- `AppState.swift` — navigation state, refresh mechanism
- `ProjectManagerViewModel`
- `SidebarView`, `ProjectSelectorView`
- `ContentView` — the three-column `NavigationSplitView` that routes sections
- Xcode project creation: file groups, build settings, bundle ID, Info.plist
- `Assets.xcassets` — app icon placeholder, accent color

**Dependencies:** Needs model type definitions from Worker A for AppState and ProjectManagerViewModel. Can stub with minimal definitions and integrate at merge.

**Deliverables:**
- App launches and displays the three-column layout
- Sidebar navigation switches between sections
- Project selector UI works (add, remove, switch)
- Keyboard shortcuts wired (Cmd+N for new issue, Cmd+R for refresh)
- Xcode project file configured and builds cleanly

---

### Merge Strategy

```
Phase 1 (parallel):  A, B, C, D all work simultaneously
                     B, C, D use model type stubs from this architecture doc

Phase 2 (integrate): Merge Worker A first (foundation).
                     Then merge B, C, D — resolve any type mismatches against A's actual types.

Phase 3 (wire up):   Worker D's ContentView imports actual views from B and C.
                     Replace any PBClient stubs with real calls.
                     Verify full navigation flow: sidebar → list → detail.
```

**Branch naming:**
- `worker-a/models-services`
- `worker-b/core-views`
- `worker-c/advanced-views`
- `worker-d/app-shell`

**Integration order:** A → D → B → C (merge A first because everything depends on it, then D for the shell, then B for the core views, then C for advanced views).

---

## 12. Design Notes

### Why shell out to `pb` instead of reading `.pebbles/` directly?

1. **Correctness**: `pb` handles cache rebuilding, ID generation, event replay. Reimplementing that logic would be fragile and drift from upstream.
2. **Simplicity**: The CLI is the stable API surface. Internal file formats may change.
3. **Consistency**: Running `pb` ensures the same behavior a terminal user would see.
4. **Trade-off**: Slightly slower than direct DB reads, but `pb` commands are fast (local SQLite) and we can cache results in ViewModels.

### JSON vs Text parsing strategy

Prefer `--json` wherever available. The pebbles CLI offers `--json` on `list`, `show`, `log`, and `ready`. Only `dep tree`, `create` output, and `version` require text parsing. This minimizes fragile regex/text parsing.

### Concurrency model

- `ProcessRunner` is an `actor` to serialize process execution (avoids concurrent writes to `.pebbles/events.jsonl`).
- ViewModels use `async/await` in `.task { }` modifiers.
- All mutations go through PBClient → ProcessRunner, ensuring sequential writes.

### macOS 14+ APIs used

- `@Observable` macro (replaces `ObservableObject` + `@Published`)
- `NavigationSplitView` with three columns
- `.inspector()` modifier (alternative for detail panel)
- Swift 5.9 `if/switch` expressions in ViewBuilder
