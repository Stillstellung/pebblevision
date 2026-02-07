import Foundation

/// Recursive tree node mirroring pebbles DepNode.
/// Used by `pb dep tree ISSUE-ID`.
struct DepNode: Identifiable {
    var id: String { issue.id }
    var issue: Issue
    var dependencies: [DepNode]
}
