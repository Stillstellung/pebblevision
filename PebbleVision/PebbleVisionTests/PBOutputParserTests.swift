import XCTest
@testable import PebbleVision

final class PBOutputParserTests: XCTestCase {
    let parser = PBOutputParser()

    // MARK: - Create Output

    func testParseCreateOutputSimple() {
        let result = parser.parseCreateOutput("pv-x9z\n")
        XCTAssertEqual(result, "pv-x9z")
    }

    func testParseCreateOutputWithCreatedPrefix() {
        let result = parser.parseCreateOutput("Created pv-abc123\n")
        XCTAssertEqual(result, "pv-abc123")
    }

    func testParseCreateOutputTrimmed() {
        let result = parser.parseCreateOutput("  pv-def  \n")
        XCTAssertEqual(result, "pv-def")
    }

    // MARK: - Version

    func testParseVersion() {
        let result = parser.parseVersion("pebbles v0.8.0\n")
        XCTAssertEqual(result, "v0.8.0")
    }

    func testParseVersionRaw() {
        let result = parser.parseVersion("v1.0.0")
        XCTAssertEqual(result, "v1.0.0")
    }

    // MARK: - Issue Line Parsing

    func testParseIssueLineOpen() {
        let issue = parser.parseIssueLine("○ pb-abc [● P2] [task] - Fix the thing")
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.id, "pb-abc")
        XCTAssertEqual(issue?.status, .open)
        XCTAssertEqual(issue?.priority, .p2)
        XCTAssertEqual(issue?.issueType, "task")
        XCTAssertEqual(issue?.title, "Fix the thing")
    }

    func testParseIssueLineInProgress() {
        let issue = parser.parseIssueLine("◐ pb-def [● P1] [bug] - Login broken")
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.status, .inProgress)
        XCTAssertEqual(issue?.issueType, "bug")
    }

    func testParseIssueLineClosed() {
        let issue = parser.parseIssueLine("● pb-ghi [● P3] [feature] - Dark mode")
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.status, .closed)
    }

    func testParseIssueLineWithDate() {
        let issue = parser.parseIssueLine("○ pb-abc [● P2] [task] [2025-01-20] - Fix the thing")
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.id, "pb-abc")
        XCTAssertEqual(issue?.title, "Fix the thing")
    }

    func testParseIssueLineWithTrailingStatus() {
        let issue = parser.parseIssueLine("○ pb-abc - Fix the thing [OPEN]")
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.status, .open)
        XCTAssertEqual(issue?.title, "Fix the thing")
    }

    func testParseIssueLineEmpty() {
        let issue = parser.parseIssueLine("")
        XCTAssertNil(issue)
    }

    // MARK: - Dep Tree Parsing

    func testParseDepTree() {
        let text = """
        pv-g7h
        ├── pv-a1b - Fix login bug [OPEN]
        │   └── pv-xyz - Set up OAuth provider [OPEN]
        └── pv-c3d - Add dark mode [IN_PROGRESS]
        """

        let tree = parser.parseDepTree(text)
        XCTAssertNotNil(tree)
        XCTAssertEqual(tree?.issue.id, "pv-g7h")
        XCTAssertEqual(tree?.dependencies.count, 2)

        let firstChild = tree?.dependencies[0]
        XCTAssertEqual(firstChild?.issue.id, "pv-a1b")
        XCTAssertEqual(firstChild?.dependencies.count, 1)

        let grandchild = firstChild?.dependencies[0]
        XCTAssertEqual(grandchild?.issue.id, "pv-xyz")
        XCTAssertEqual(grandchild?.dependencies.count, 0)

        let secondChild = tree?.dependencies[1]
        XCTAssertEqual(secondChild?.issue.id, "pv-c3d")
    }

    func testParseDepTreeEmpty() {
        let tree = parser.parseDepTree("")
        XCTAssertNil(tree)
    }

    func testParseDepTreeSingleNode() {
        let tree = parser.parseDepTree("pv-abc\n")
        XCTAssertNotNil(tree)
        XCTAssertEqual(tree?.issue.id, "pv-abc")
        XCTAssertEqual(tree?.dependencies.count, 0)
    }
}
