import Foundation

/// A single entry from `pb log --json`. Each event is a JSON line.
struct Event: Identifiable, Sendable {
    var id: String { "\(issueID)-\(timestamp.timeIntervalSince1970)-\(type)" }

    var line: Int?
    var timestamp: Date
    var type: String
    var label: String?
    var issueID: String
    var issueTitle: String?
    var actor: String?
    var actorDate: String?
    var details: String?
    var payload: [String: String]

    enum CodingKeys: String, CodingKey {
        case line, timestamp, type, label
        case issueID = "issue_id"
        case issueTitle = "issue_title"
        case actor
        case actorDate = "actor_date"
        case details, payload
    }
}

extension Event: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        line = try container.decodeIfPresent(Int.self, forKey: .line)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        type = try container.decode(String.self, forKey: .type)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        issueID = try container.decode(String.self, forKey: .issueID)
        issueTitle = try container.decodeIfPresent(String.self, forKey: .issueTitle)
        actor = try container.decodeIfPresent(String.self, forKey: .actor)
        actorDate = try container.decodeIfPresent(String.self, forKey: .actorDate)
        details = try container.decodeIfPresent(String.self, forKey: .details)
        payload = try container.decodeIfPresent([String: String].self, forKey: .payload) ?? [:]
    }
}

extension Event: Encodable {}
