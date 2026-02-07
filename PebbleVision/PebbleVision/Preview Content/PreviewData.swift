import Foundation

/// Sample data for SwiftUI previews and testing.
enum PreviewData {
    // MARK: - Sample Project

    static let project = Project(
        name: "PebbleVision",
        path: "/Users/dev/pebbleVision",
        prefix: "pv",
        lastOpened: Date()
    )

    static let sampleProject = project

    // MARK: - Sample Issues

    static let sampleIssues: [Issue] = [
        Issue(
            id: "pv-a1b",
            title: "Fix login bug",
            description: "Users can't log in with SSO. The OAuth callback URL is wrong.",
            issueType: "bug",
            status: .open,
            priority: .p1,
            createdAt: ISO8601DateFormatter().date(from: "2025-01-20T10:30:00Z"),
            updatedAt: ISO8601DateFormatter().date(from: "2025-01-20T12:00:00Z"),
            parents: ["pv-g7h"],
            children: ["pv-a1b.1", "pv-a1b.2"],
            deps: ["pv-xyz"],
            comments: [
                IssueComment(
                    body: "Confirmed this affects all SSO providers.",
                    timestamp: ISO8601DateFormatter().date(from: "2025-01-20T11:00:00Z")!
                ),
                IssueComment(
                    body: "Root cause identified in config.",
                    timestamp: ISO8601DateFormatter().date(from: "2025-01-20T12:00:00Z")!
                ),
            ]
        ),
        Issue(
            id: "pv-c3d",
            title: "Add dark mode",
            description: "Implement dark theme support across the application.",
            issueType: "feature",
            status: .inProgress,
            priority: .p2,
            createdAt: ISO8601DateFormatter().date(from: "2025-01-21T09:00:00Z"),
            updatedAt: ISO8601DateFormatter().date(from: "2025-01-22T14:30:00Z"),
            deps: []
        ),
        Issue(
            id: "pv-e5f",
            title: "Update dependencies",
            description: "Bump all outdated packages to latest versions.",
            issueType: "chore",
            status: .closed,
            priority: .p3,
            createdAt: ISO8601DateFormatter().date(from: "2025-01-15T08:00:00Z"),
            updatedAt: ISO8601DateFormatter().date(from: "2025-01-18T16:00:00Z"),
            closedAt: ISO8601DateFormatter().date(from: "2025-01-18T16:00:00Z"),
            deps: []
        ),
        Issue(
            id: "pv-g7h",
            title: "Design epic: v2.0 release",
            description: "Epic tracking all work for the v2.0 release milestone.",
            issueType: "epic",
            status: .open,
            priority: .p0,
            createdAt: ISO8601DateFormatter().date(from: "2025-01-10T10:00:00Z"),
            updatedAt: ISO8601DateFormatter().date(from: "2025-01-25T09:00:00Z"),
            children: ["pv-a1b", "pv-c3d"],
            deps: []
        ),
        Issue(
            id: "pv-i9j",
            title: "Write API documentation",
            description: "Document all REST endpoints with examples.",
            issueType: "task",
            status: .closed,
            priority: .p4,
            createdAt: ISO8601DateFormatter().date(from: "2025-01-14T08:00:00Z"),
            updatedAt: ISO8601DateFormatter().date(from: "2025-01-19T16:00:00Z"),
            closedAt: ISO8601DateFormatter().date(from: "2025-01-19T16:00:00Z"),
            deps: []
        ),
    ]

    static let issues = sampleIssues
    static let sampleIssue: Issue = sampleIssues[0]

    // MARK: - Sample Comments

    static let sampleComments: [IssueComment] = [
        IssueComment(
            body: "Confirmed this affects all SSO providers.",
            timestamp: ISO8601DateFormatter().date(from: "2025-01-20T11:00:00Z")!
        ),
        IssueComment(
            body: "Root cause identified in config. The callback URL is using HTTP instead of HTTPS.",
            timestamp: ISO8601DateFormatter().date(from: "2025-01-20T12:00:00Z")!
        ),
    ]

    // MARK: - Sample Events

    static let sampleEvents: [Event] = [
        Event(
            line: 1,
            timestamp: ISO8601DateFormatter().date(from: "2025-01-20T10:30:00Z")!,
            type: "create",
            label: "create",
            issueID: "pv-a1b",
            issueTitle: "Fix login bug",
            actor: "Joel",
            actorDate: "2025-01-20",
            details: "type=bug priority=P1",
            payload: ["title": "Fix login bug", "type": "bug", "priority": "1"]
        ),
        Event(
            line: 2,
            timestamp: ISO8601DateFormatter().date(from: "2025-01-20T11:00:00Z")!,
            type: "comment",
            label: "comment",
            issueID: "pv-a1b",
            issueTitle: "Fix login bug",
            actor: "Joel",
            actorDate: "2025-01-20",
            details: nil,
            payload: ["body": "Confirmed this affects all SSO providers."]
        ),
        Event(
            line: 3,
            timestamp: ISO8601DateFormatter().date(from: "2025-01-21T09:00:00Z")!,
            type: "create",
            label: "create",
            issueID: "pv-c3d",
            issueTitle: "Add dark mode",
            actor: "Alice",
            actorDate: "2025-01-21",
            details: "type=feature priority=P2",
            payload: ["title": "Add dark mode", "type": "feature", "priority": "2"]
        ),
    ]

    // MARK: - Sample Dependency Tree

    static let sampleDepNode = DepNode(
        issue: sampleIssues[3], // epic
        dependencies: [
            DepNode(
                issue: sampleIssues[0], // bug
                dependencies: []
            ),
            DepNode(
                issue: sampleIssues[1], // feature
                dependencies: []
            ),
        ]
    )

    // MARK: - Preview Helpers (for SwiftUI previews)

    static let client = PBClient()
    static let projectStore: ProjectStore = {
        let store = ProjectStore()
        return store
    }()

    // MARK: - Sample JSON Strings (matching real pb output)

    /// Sample `pb list --json` output.
    static let sampleListJSON = """
    [
      {
        "id": "pv-a1b",
        "title": "Fix login bug",
        "description": "Users can't log in with SSO",
        "type": "bug",
        "status": "open",
        "priority": "P1",
        "created_at": "2025-01-20T10:30:00Z",
        "updated_at": "2025-01-20T12:00:00Z",
        "closed_at": "",
        "deps": ["pv-xyz"]
      },
      {
        "id": "pv-c3d",
        "title": "Add dark mode",
        "description": "Implement dark theme support",
        "type": "feature",
        "status": "in_progress",
        "priority": "P2",
        "created_at": "2025-01-21T09:00:00Z",
        "updated_at": "2025-01-22T14:30:00Z",
        "closed_at": "",
        "deps": []
      }
    ]
    """

    /// Sample `pb show --json` output.
    static let sampleShowJSON = """
    {
      "id": "pv-a1b",
      "title": "Fix login bug",
      "description": "Users can't log in with SSO. The OAuth callback URL is wrong.",
      "type": "bug",
      "status": "open",
      "priority": "P1",
      "created_at": "2025-01-20T10:30:00Z",
      "updated_at": "2025-01-20T12:00:00Z",
      "closed_at": "",
      "deps": ["pv-xyz"],
      "parents": ["pv-g7h"],
      "siblings": [],
      "children": [],
      "comments": [
        {
          "body": "Confirmed this affects all SSO providers.",
          "timestamp": "2025-01-20T11:00:00Z"
        },
        {
          "body": "Root cause identified in config.",
          "timestamp": "2025-01-20T12:00:00Z"
        }
      ]
    }
    """

    /// Sample `pb log --json` output (line-delimited, one object per line).
    static let sampleLogJSON = """
    {"line":1,"timestamp":"2025-01-20T10:30:00Z","type":"create","label":"create","issue_id":"pv-a1b","issue_title":"Fix login bug","actor":"Joel","actor_date":"2025-01-20","details":"type=bug priority=P1","payload":{"title":"Fix login bug","type":"bug","priority":"1","description":"Users can't log in with SSO"}}
    {"line":2,"timestamp":"2025-01-20T11:00:00Z","type":"comment","label":"comment","issue_id":"pv-a1b","issue_title":"Fix login bug","actor":"Joel","actor_date":"2025-01-20","details":"","payload":{"body":"Confirmed this affects all SSO providers."}}
    {"line":3,"timestamp":"2025-01-21T09:00:00Z","type":"create","label":"create","issue_id":"pv-c3d","issue_title":"Add dark mode","actor":"Alice","actor_date":"2025-01-21","details":"type=feature priority=P2","payload":{"title":"Add dark mode","type":"feature","priority":"2","description":"Implement dark theme support"}}
    """

    /// Sample `pb create` output.
    static let sampleCreateOutput = "pv-x9z\n"

    /// Sample `pb dep tree` output.
    static let sampleDepTreeOutput = """
    pv-g7h
    ├── pv-a1b - Fix login bug [OPEN]
    │   └── pv-xyz - Set up OAuth provider [OPEN]
    └── pv-c3d - Add dark mode [IN_PROGRESS]
    """

    /// Sample `pb version` output.
    static let sampleVersionOutput = "pebbles v0.8.0\n"
}
