import Foundation

/// A comment on a pebbles issue.
struct IssueComment: Identifiable, Hashable, Codable, Sendable {
    var body: String
    var timestamp: Date

    var id: String { "\(body.hashValue)-\(timestamp.timeIntervalSince1970)" }
}
