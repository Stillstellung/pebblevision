import Foundation

/// A registered project (repo) that PebbleVision can manage.
struct Project: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var path: String
    var prefix: String
    var lastOpened: Date?
}
