import Foundation

/// Issue lifecycle status.
enum IssueStatus: String, Codable, CaseIterable, Sendable {
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

    var sortOrder: Int {
        switch self {
        case .open: 0
        case .inProgress: 1
        case .closed: 2
        }
    }
}

/// Sort field for issue lists.
enum IssueSortField: String, CaseIterable {
    case date = "Date"
    case priority = "Priority"
    case type = "Type"
    case status = "Status"
}

/// Severity level P0 (critical) through P4 (trivial).
/// In JSON output, priority is a label string ("P0"–"P4").
/// In SQLite/events, it's an integer (0–4).
enum Priority: Int, Codable, CaseIterable, Comparable, Sendable {
    case p0 = 0, p1 = 1, p2 = 2, p3 = 3, p4 = 4

    var label: String { "P\(rawValue)" }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Initialize from a label string like "P0", "P1", etc.
    init?(label: String) {
        let upper = label.uppercased()
        guard upper.hasPrefix("P"),
              let digit = Int(upper.dropFirst()),
              let p = Priority(rawValue: digit) else {
            return nil
        }
        self = p
    }
}

/// Event types from the pebbles event log.
enum EventType: String, Codable, Sendable {
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
