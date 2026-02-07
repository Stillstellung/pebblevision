import Foundation

/// Parses JSON output from pb CLI commands.
struct PBJSONParser {
    private let decoder: JSONDecoder

    init() {
        let decoder = JSONDecoder()
        // NOTE: Do NOT use .convertFromSnakeCase here — all types use explicit CodingKeys
        // for snake_case mapping. Using the strategy would double-convert and cause mismatches.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if string.isEmpty {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Empty date string"
                )
            }
            if let date = DateFormatting.parseDate(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(string)"
            )
        }
        self.decoder = decoder
    }

    /// Parse `pb list --json` output. Returns array of Issue.
    func parseIssueList(_ json: String) throws -> [Issue] {
        guard let data = json.data(using: .utf8) else {
            throw PBError.parseError(detail: "Invalid UTF-8 in JSON")
        }
        let raw = try decoder.decode([RawIssue].self, from: data)
        return raw.map { $0.toIssue() }
    }

    /// Parse `pb show --json` output. Returns Issue with full detail.
    func parseIssueDetail(_ json: String) throws -> Issue {
        guard let data = json.data(using: .utf8) else {
            throw PBError.parseError(detail: "Invalid UTF-8 in JSON")
        }
        let raw = try decoder.decode(RawIssueDetail.self, from: data)
        return raw.toIssue()
    }

    /// Parse `pb log --json` output. Each line is a JSON object (line-delimited, NOT an array).
    func parseEventLog(_ jsonLines: String) throws -> [Event] {
        var events: [Event] = []
        let lines = jsonLines.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8) else { continue }
            let event = try decoder.decode(Event.self, from: data)
            events.append(event)
        }
        return events
    }

    /// Parse `pb ready --json` output. Same shape as list.
    func parseReadyList(_ json: String) throws -> [Issue] {
        try parseIssueList(json)
    }
}

// MARK: - Raw JSON Structures

/// Intermediate struct for decoding pb JSON where priority is a string label ("P0"-"P4")
/// and closed_at can be an empty string.
private struct RawIssue: Decodable {
    let id: String
    let title: String
    let description: String
    let issueType: String
    let status: String
    let priority: String
    let createdAt: String?
    let updatedAt: String?
    let closedAt: String?
    let deps: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case issueType = "type"
        case status, priority
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case deps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        issueType = try container.decodeIfPresent(String.self, forKey: .issueType) ?? "task"
        status = try container.decode(String.self, forKey: .status)
        priority = try container.decode(String.self, forKey: .priority)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        closedAt = try container.decodeIfPresent(String.self, forKey: .closedAt)
        deps = try container.decodeIfPresent([String].self, forKey: .deps) ?? []
    }

    func toIssue() -> Issue {
        Issue(
            id: id,
            title: title,
            description: description,
            issueType: issueType,
            status: IssueStatus(rawValue: status) ?? .open,
            priority: Priority(label: priority) ?? .p2,
            createdAt: parseOptionalDate(createdAt),
            updatedAt: parseOptionalDate(updatedAt),
            closedAt: parseOptionalDate(closedAt),
            deps: deps
        )
    }
}

/// Extended issue detail from `pb show --json` with hierarchy and comments.
private struct RawIssueDetail: Decodable {
    let id: String
    let title: String
    let description: String
    let issueType: String
    let status: String
    let priority: String
    let createdAt: String?
    let updatedAt: String?
    let closedAt: String?
    let deps: [String]
    let parents: [String]?
    let siblings: [String]?
    let children: [String]?
    let comments: [RawComment]?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case issueType = "type"
        case status, priority
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case deps, parents, siblings, children, comments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        issueType = try container.decodeIfPresent(String.self, forKey: .issueType) ?? "task"
        status = try container.decode(String.self, forKey: .status)
        priority = try container.decode(String.self, forKey: .priority)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        closedAt = try container.decodeIfPresent(String.self, forKey: .closedAt)
        deps = try container.decodeIfPresent([String].self, forKey: .deps) ?? []
        parents = try container.decodeIfPresent([String].self, forKey: .parents)
        siblings = try container.decodeIfPresent([String].self, forKey: .siblings)
        children = try container.decodeIfPresent([String].self, forKey: .children)
        comments = try container.decodeIfPresent([RawComment].self, forKey: .comments)
    }

    func toIssue() -> Issue {
        Issue(
            id: id,
            title: title,
            description: description,
            issueType: issueType,
            status: IssueStatus(rawValue: status) ?? .open,
            priority: Priority(label: priority) ?? .p2,
            createdAt: parseOptionalDate(createdAt),
            updatedAt: parseOptionalDate(updatedAt),
            closedAt: parseOptionalDate(closedAt),
            parents: parents,
            children: children,
            siblings: siblings,
            deps: deps,
            comments: comments?.map { $0.toIssueComment() }
        )
    }
}

private struct RawComment: Decodable {
    let body: String
    let timestamp: String

    func toIssueComment() -> IssueComment {
        IssueComment(
            body: body,
            timestamp: DateFormatting.parseDate(timestamp) ?? Date()
        )
    }
}

/// Parse date from string, returning nil for empty/invalid strings.
private func parseOptionalDate(_ string: String?) -> Date? {
    guard let string, !string.isEmpty else { return nil }
    return DateFormatting.parseDate(string)
}
