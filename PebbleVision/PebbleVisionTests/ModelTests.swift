import XCTest
@testable import PebbleVision

final class ModelTests: XCTestCase {

    // MARK: - Issue Codable Round-trip

    func testIssueCodableRoundTrip() throws {
        let issue = Issue(
            id: "pv-abc",
            title: "Test issue",
            description: "A test description",
            issueType: "bug",
            status: .open,
            priority: .p1,
            createdAt: Date(timeIntervalSince1970: 1706000000),
            updatedAt: Date(timeIntervalSince1970: 1706001000),
            closedAt: nil,
            parents: ["pv-parent"],
            children: ["pv-child"],
            siblings: [],
            deps: ["pv-dep1", "pv-dep2"],
            comments: [
                IssueComment(body: "A comment", timestamp: Date(timeIntervalSince1970: 1706002000))
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(issue)
        let decoded = try JSONDecoder().decode(Issue.self, from: data)

        XCTAssertEqual(decoded.id, issue.id)
        XCTAssertEqual(decoded.title, issue.title)
        XCTAssertEqual(decoded.description, issue.description)
        XCTAssertEqual(decoded.issueType, issue.issueType)
        XCTAssertEqual(decoded.status, issue.status)
        XCTAssertEqual(decoded.priority, issue.priority)
        XCTAssertEqual(decoded.deps, issue.deps)
        XCTAssertEqual(decoded.parents, issue.parents)
        XCTAssertEqual(decoded.children, issue.children)
        XCTAssertEqual(decoded.comments?.count, 1)
    }

    func testIssueHashable() {
        let issue1 = Issue(
            id: "pv-abc", title: "Test", description: "", issueType: "task",
            status: .open, priority: .p2, deps: []
        )
        let issue2 = Issue(
            id: "pv-abc", title: "Test", description: "", issueType: "task",
            status: .open, priority: .p2, deps: []
        )
        let issue3 = Issue(
            id: "pv-def", title: "Other", description: "", issueType: "bug",
            status: .closed, priority: .p0, deps: []
        )

        XCTAssertEqual(issue1, issue2)
        XCTAssertNotEqual(issue1, issue3)

        var set: Set<Issue> = []
        set.insert(issue1)
        set.insert(issue2)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Event Codable Round-trip

    func testEventCodableRoundTrip() throws {
        let event = Event(
            line: 1,
            timestamp: Date(timeIntervalSince1970: 1706000000),
            type: "create",
            label: "create",
            issueID: "pv-abc",
            issueTitle: "Test issue",
            actor: "Joel",
            actorDate: "2025-01-20",
            details: "type=bug",
            payload: ["title": "Test issue", "type": "bug"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let decoded = try JSONDecoder().decode(Event.self, from: data)

        XCTAssertEqual(decoded.type, event.type)
        XCTAssertEqual(decoded.issueID, event.issueID)
        XCTAssertEqual(decoded.issueTitle, event.issueTitle)
        XCTAssertEqual(decoded.actor, event.actor)
        XCTAssertEqual(decoded.payload, event.payload)
    }

    func testEventIdentity() {
        let event = Event(
            line: 1,
            timestamp: Date(timeIntervalSince1970: 1706000000),
            type: "create",
            label: "create",
            issueID: "pv-abc",
            payload: ["title": "Test"]
        )

        XCTAssertTrue(event.id.contains("pv-abc"))
        XCTAssertTrue(event.id.contains("create"))
    }

    // MARK: - Project Codable Round-trip

    func testProjectCodableRoundTrip() throws {
        let project = Project(
            name: "TestProject",
            path: "/Users/test/project",
            prefix: "tp",
            lastOpened: Date(timeIntervalSince1970: 1706000000)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.id, project.id)
        XCTAssertEqual(decoded.name, project.name)
        XCTAssertEqual(decoded.path, project.path)
        XCTAssertEqual(decoded.prefix, project.prefix)
    }

    func testProjectHashable() {
        let id = UUID()
        let project1 = Project(id: id, name: "Test", path: "/test", prefix: "t")
        let project2 = Project(id: id, name: "Test", path: "/test", prefix: "t")

        XCTAssertEqual(project1, project2)
    }

    // MARK: - IssueComment Codable Round-trip

    func testIssueCommentCodableRoundTrip() throws {
        let comment = IssueComment(
            body: "This is a comment",
            timestamp: Date(timeIntervalSince1970: 1706000000)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(comment)
        let decoded = try JSONDecoder().decode(IssueComment.self, from: data)

        XCTAssertEqual(decoded.body, comment.body)
    }

    // MARK: - IssueStatus

    func testIssueStatusRawValues() {
        XCTAssertEqual(IssueStatus.open.rawValue, "open")
        XCTAssertEqual(IssueStatus.inProgress.rawValue, "in_progress")
        XCTAssertEqual(IssueStatus.closed.rawValue, "closed")
    }

    func testIssueStatusDisplayName() {
        XCTAssertEqual(IssueStatus.open.displayName, "Open")
        XCTAssertEqual(IssueStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(IssueStatus.closed.displayName, "Closed")
    }

    func testIssueStatusFromRawValue() {
        XCTAssertEqual(IssueStatus(rawValue: "open"), .open)
        XCTAssertEqual(IssueStatus(rawValue: "in_progress"), .inProgress)
        XCTAssertEqual(IssueStatus(rawValue: "closed"), .closed)
        XCTAssertNil(IssueStatus(rawValue: "invalid"))
    }

    // MARK: - Priority

    func testPriorityLabels() {
        XCTAssertEqual(Priority.p0.label, "P0")
        XCTAssertEqual(Priority.p1.label, "P1")
        XCTAssertEqual(Priority.p2.label, "P2")
        XCTAssertEqual(Priority.p3.label, "P3")
        XCTAssertEqual(Priority.p4.label, "P4")
    }

    func testPriorityFromLabel() {
        XCTAssertEqual(Priority(label: "P0"), .p0)
        XCTAssertEqual(Priority(label: "P1"), .p1)
        XCTAssertEqual(Priority(label: "P4"), .p4)
        XCTAssertEqual(Priority(label: "p2"), .p2, "Should be case-insensitive")
        XCTAssertNil(Priority(label: "P5"))
        XCTAssertNil(Priority(label: "invalid"))
    }

    func testPriorityComparable() {
        XCTAssertTrue(Priority.p0 < Priority.p1)
        XCTAssertTrue(Priority.p1 < Priority.p4)
        XCTAssertFalse(Priority.p3 < Priority.p2)
    }

    // MARK: - PBError

    func testPBErrorDescriptions() {
        XCTAssertNotNil(PBError.notInitialized(path: "/test").errorDescription)
        XCTAssertNotNil(PBError.issueNotFound(id: "pv-abc").errorDescription)
        XCTAssertNotNil(PBError.commandFailed(stderr: "err", exitCode: 1).errorDescription)
        XCTAssertNotNil(PBError.parseError(detail: "bad data").errorDescription)
        XCTAssertNotNil(PBError.pbNotFound(path: "/usr/local/bin/pb").errorDescription)
        XCTAssertNotNil(PBError.timeout.errorDescription)
        XCTAssertNotNil(PBError.unexpected("something").errorDescription)
    }

    func testPBErrorEquatable() {
        XCTAssertEqual(PBError.timeout, PBError.timeout)
        XCTAssertEqual(
            PBError.commandFailed(stderr: "err", exitCode: 1),
            PBError.commandFailed(stderr: "err", exitCode: 1)
        )
        XCTAssertNotEqual(PBError.timeout, PBError.unexpected("timeout"))
    }
}
