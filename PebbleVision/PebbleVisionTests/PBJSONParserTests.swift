import XCTest
@testable import PebbleVision

final class PBJSONParserTests: XCTestCase {
    let parser = PBJSONParser()

    // MARK: - Issue List Parsing

    func testParseIssueList() throws {
        let json = """
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
            "description": "",
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

        let issues = try parser.parseIssueList(json)
        XCTAssertEqual(issues.count, 2)

        let first = issues[0]
        XCTAssertEqual(first.id, "pv-a1b")
        XCTAssertEqual(first.title, "Fix login bug")
        XCTAssertEqual(first.issueType, "bug")
        XCTAssertEqual(first.status, .open)
        XCTAssertEqual(first.priority, .p1)
        XCTAssertNotNil(first.createdAt)
        XCTAssertNotNil(first.updatedAt)
        XCTAssertNil(first.closedAt, "closed_at should be nil when empty string")
        XCTAssertEqual(first.deps, ["pv-xyz"])

        let second = issues[1]
        XCTAssertEqual(second.id, "pv-c3d")
        XCTAssertEqual(second.status, .inProgress)
        XCTAssertEqual(second.priority, .p2)
        XCTAssertEqual(second.deps, [])
    }

    func testParseIssueListEmpty() throws {
        let issues = try parser.parseIssueList("[]")
        XCTAssertTrue(issues.isEmpty)
    }

    func testParseIssueListClosedIssue() throws {
        let json = """
        [
          {
            "id": "pv-e5f",
            "title": "Update deps",
            "description": "Bump packages",
            "type": "chore",
            "status": "closed",
            "priority": "P3",
            "created_at": "2025-01-15T08:00:00Z",
            "updated_at": "2025-01-18T16:00:00Z",
            "closed_at": "2025-01-18T16:00:00Z",
            "deps": []
          }
        ]
        """

        let issues = try parser.parseIssueList(json)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].status, .closed)
        XCTAssertNotNil(issues[0].closedAt, "closed_at should be non-nil for closed issues")
    }

    // MARK: - Issue Detail Parsing

    func testParseIssueDetail() throws {
        let json = """
        {
          "id": "pv-a1b",
          "title": "Fix login bug",
          "description": "Users can't log in with SSO.",
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

        let issue = try parser.parseIssueDetail(json)
        XCTAssertEqual(issue.id, "pv-a1b")
        XCTAssertEqual(issue.parents, ["pv-g7h"])
        XCTAssertEqual(issue.siblings, [])
        XCTAssertEqual(issue.children, [])
        XCTAssertEqual(issue.comments?.count, 2)
        XCTAssertEqual(issue.comments?[0].body, "Confirmed this affects all SSO providers.")
    }

    func testParseIssueDetailNoComments() throws {
        let json = """
        {
          "id": "pv-c3d",
          "title": "Add dark mode",
          "description": "Implement dark theme",
          "type": "feature",
          "status": "in_progress",
          "priority": "P2",
          "created_at": "2025-01-21T09:00:00Z",
          "updated_at": "2025-01-22T14:30:00Z",
          "closed_at": "",
          "deps": [],
          "parents": [],
          "siblings": [],
          "children": []
        }
        """

        let issue = try parser.parseIssueDetail(json)
        XCTAssertEqual(issue.id, "pv-c3d")
        XCTAssertNil(issue.comments)
    }

    // MARK: - Event Log Parsing

    func testParseEventLog() throws {
        let jsonLines = """
        {"line":1,"timestamp":"2025-01-20T10:30:00Z","type":"create","label":"create","issue_id":"pv-a1b","issue_title":"Fix login bug","actor":"Joel","actor_date":"2025-01-20","details":"type=bug priority=P1","payload":{"title":"Fix login bug","type":"bug","priority":"1"}}
        {"line":2,"timestamp":"2025-01-20T11:00:00Z","type":"comment","label":"comment","issue_id":"pv-a1b","issue_title":"Fix login bug","actor":"Joel","actor_date":"2025-01-20","details":"","payload":{"body":"Confirmed this affects all SSO providers."}}
        """

        let events = try parser.parseEventLog(jsonLines)
        XCTAssertEqual(events.count, 2)

        let first = events[0]
        XCTAssertEqual(first.line, 1)
        XCTAssertEqual(first.type, "create")
        XCTAssertEqual(first.label, "create")
        XCTAssertEqual(first.issueID, "pv-a1b")
        XCTAssertEqual(first.issueTitle, "Fix login bug")
        XCTAssertEqual(first.actor, "Joel")
        XCTAssertEqual(first.actorDate, "2025-01-20")
        XCTAssertEqual(first.payload["title"], "Fix login bug")

        let second = events[1]
        XCTAssertEqual(second.type, "comment")
        XCTAssertEqual(second.payload["body"], "Confirmed this affects all SSO providers.")
    }

    func testParseEventLogEmptyInput() throws {
        let events = try parser.parseEventLog("")
        XCTAssertTrue(events.isEmpty)
    }

    func testParseEventLogWithTrailingNewline() throws {
        let jsonLines = """
        {"line":1,"timestamp":"2025-01-20T10:30:00Z","type":"create","label":"create","issue_id":"pv-a1b","payload":{"title":"Test"}}

        """

        let events = try parser.parseEventLog(jsonLines)
        XCTAssertEqual(events.count, 1)
    }

    // MARK: - Ready List Parsing

    func testParseReadyList() throws {
        let json = """
        [
          {
            "id": "pv-c3d",
            "title": "Add dark mode",
            "description": "Implement dark theme",
            "type": "feature",
            "status": "open",
            "priority": "P2",
            "created_at": "2025-01-21T09:00:00Z",
            "updated_at": "2025-01-22T14:30:00Z",
            "closed_at": "",
            "deps": []
          }
        ]
        """

        let issues = try parser.parseReadyList(json)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].id, "pv-c3d")
    }

    // MARK: - Edge Cases

    func testEmptyClosedAtHandling() throws {
        let json = """
        [
          {
            "id": "pv-test",
            "title": "Test issue",
            "description": "",
            "type": "task",
            "status": "open",
            "priority": "P2",
            "created_at": "2025-01-20T10:30:00Z",
            "updated_at": "2025-01-20T10:30:00Z",
            "closed_at": "",
            "deps": []
          }
        ]
        """

        let issues = try parser.parseIssueList(json)
        XCTAssertNil(issues[0].closedAt, "Empty string closed_at should be nil")
    }

    func testPriorityAsStringLabel() throws {
        let json = """
        [
          {
            "id": "pv-p0",
            "title": "Critical",
            "description": "",
            "type": "bug",
            "status": "open",
            "priority": "P0",
            "created_at": "2025-01-20T10:30:00Z",
            "updated_at": "2025-01-20T10:30:00Z",
            "closed_at": "",
            "deps": []
          },
          {
            "id": "pv-p4",
            "title": "Trivial",
            "description": "",
            "type": "task",
            "status": "open",
            "priority": "P4",
            "created_at": "2025-01-20T10:30:00Z",
            "updated_at": "2025-01-20T10:30:00Z",
            "closed_at": "",
            "deps": []
          }
        ]
        """

        let issues = try parser.parseIssueList(json)
        XCTAssertEqual(issues[0].priority, .p0)
        XCTAssertEqual(issues[1].priority, .p4)
    }

    func testFreeFormIssueType() throws {
        let json = """
        [
          {
            "id": "pv-custom",
            "title": "Custom type issue",
            "description": "",
            "type": "investigation",
            "status": "open",
            "priority": "P2",
            "created_at": "2025-01-20T10:30:00Z",
            "updated_at": "2025-01-20T10:30:00Z",
            "closed_at": "",
            "deps": []
          }
        ]
        """

        let issues = try parser.parseIssueList(json)
        XCTAssertEqual(issues[0].issueType, "investigation")
    }

    func testMissingOptionalFields() throws {
        let json = """
        [
          {
            "id": "pv-min",
            "title": "Minimal issue",
            "status": "open",
            "priority": "P2",
            "deps": []
          }
        ]
        """

        let issues = try parser.parseIssueList(json)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].description, "")
        XCTAssertEqual(issues[0].issueType, "task")
    }

    func testDepsAlwaysArray() throws {
        let json = """
        [
          {
            "id": "pv-test",
            "title": "Test",
            "description": "",
            "type": "task",
            "status": "open",
            "priority": "P2",
            "created_at": "2025-01-20T10:30:00Z",
            "updated_at": "2025-01-20T10:30:00Z",
            "closed_at": "",
            "deps": []
          }
        ]
        """

        let issues = try parser.parseIssueList(json)
        XCTAssertEqual(issues[0].deps, [])
    }

    func testFractionalSeconds() throws {
        let json = """
        [
          {
            "id": "pv-frac",
            "title": "Fractional seconds test",
            "description": "",
            "type": "task",
            "status": "open",
            "priority": "P2",
            "created_at": "2025-01-20T10:30:00.123456789Z",
            "updated_at": "2025-01-20T10:30:00.123456789Z",
            "closed_at": "",
            "deps": []
          }
        ]
        """

        let issues = try parser.parseIssueList(json)
        XCTAssertNotNil(issues[0].createdAt)
    }
}
