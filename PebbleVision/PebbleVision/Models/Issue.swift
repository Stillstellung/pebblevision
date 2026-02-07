import Foundation

/// Represents a pebbles issue. Parsed from `pb list --json` or `pb show --json`.
/// Note: `issueType` is a free-form String, not an enum.
struct Issue: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var title: String
    var description: String
    var issueType: String
    var status: IssueStatus
    var priority: Priority
    var createdAt: Date?
    var updatedAt: Date?
    var closedAt: Date?

    // Populated from `pb show --json` detail response
    var parents: [String]?
    var children: [String]?
    var siblings: [String]?
    var deps: [String]
    var comments: [IssueComment]?
}
