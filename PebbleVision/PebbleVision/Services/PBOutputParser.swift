import Foundation

/// Parses text output from pb commands that lack `--json` support.
struct PBOutputParser {
    /// Parse `pb create` output to extract the new issue ID.
    /// Expected: "pb-abc123\n" or "Created pb-abc123\n"
    func parseCreateOutput(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle "Created <id>" format
        if trimmed.lowercased().hasPrefix("created ") {
            return String(trimmed.dropFirst("created ".count))
                .trimmingCharacters(in: .whitespaces)
        }

        // Otherwise the entire output is the ID
        return trimmed
    }

    /// Parse `pb dep tree` text output into a DepNode tree.
    /// Output uses box-drawing characters or indentation for depth:
    /// ```
    /// pb-epic1
    /// ├── pb-epic1.1 - Design phase [OPEN]
    /// │   └── pb-epic1.2 - Implementation [OPEN]
    /// └── pb-epic1.3 - Testing [OPEN]
    /// ```
    func parseDepTree(_ text: String) -> DepNode? {
        let lines = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return nil }

        var nodes: [(depth: Int, issue: Issue)] = []

        for line in lines {
            let depth = measureDepth(line)
            let cleaned = cleanTreeLine(line)
            if let issue = parseIssueLine(cleaned) {
                nodes.append((depth, issue))
            } else {
                // Root line might just be an ID
                let id = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                if !id.isEmpty {
                    let issue = Issue(
                        id: id, title: "", description: "",
                        issueType: "task", status: .open, priority: .p2,
                        deps: []
                    )
                    nodes.append((depth, issue))
                }
            }
        }

        guard !nodes.isEmpty else { return nil }
        return buildTree(from: nodes, index: 0, parentDepth: -1).node
    }

    /// Parse a single issue line from list/tree output.
    /// Format: "○ pb-abc [● P2] [task] - Title"
    /// Status indicator: ○ = open, ◑/◐ = in_progress, ● = closed
    func parseIssueLine(_ line: String) -> Issue? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var remaining = trimmed
        var status: IssueStatus = .open

        // Parse status indicator
        if remaining.hasPrefix("○") {
            status = .open
            remaining = String(remaining.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if remaining.hasPrefix("◑") || remaining.hasPrefix("◐") {
            status = .inProgress
            remaining = String(remaining.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if remaining.hasPrefix("●") {
            status = .closed
            remaining = String(remaining.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        // Extract issue ID (first non-bracket token)
        let parts = remaining.split(separator: " ", maxSplits: 1)
        guard let idPart = parts.first else { return nil }
        let id = String(idPart)
        remaining = parts.count > 1 ? String(parts[1]) : ""

        // Parse priority from [● P2] pattern
        var priority: Priority = .p2
        if let priorityMatch = remaining.range(of: #"\[●?\s*P(\d)\]"#, options: .regularExpression) {
            let matched = String(remaining[priorityMatch])
            if let digit = matched.last(where: { $0.isNumber }),
               let intVal = Int(String(digit)),
               let p = Priority(rawValue: intVal) {
                priority = p
            }
            remaining.removeSubrange(priorityMatch)
            remaining = remaining.trimmingCharacters(in: .whitespaces)
        }

        // Parse type from [task] pattern
        var issueType = "task"
        if let typeMatch = remaining.range(of: #"\[(\w+)\]"#, options: .regularExpression) {
            let matched = String(remaining[typeMatch])
            issueType = String(matched.dropFirst().dropLast())
            remaining.removeSubrange(typeMatch)
            remaining = remaining.trimmingCharacters(in: .whitespaces)
        }

        // Remove date bracket if present [2025-01-20]
        if let dateMatch = remaining.range(of: #"\[\d{4}-\d{2}-\d{2}\]"#, options: .regularExpression) {
            remaining.removeSubrange(dateMatch)
            remaining = remaining.trimmingCharacters(in: .whitespaces)
        }

        // Remove leading dash separator
        if remaining.hasPrefix("- ") {
            remaining = String(remaining.dropFirst(2))
        } else if remaining.hasPrefix("-") {
            remaining = String(remaining.dropFirst())
        }
        let title = remaining.trimmingCharacters(in: .whitespaces)

        // Parse status from trailing [OPEN], [IN_PROGRESS], [CLOSED]
        var finalTitle = title
        if finalTitle.hasSuffix("[OPEN]") {
            status = .open
            finalTitle = String(finalTitle.dropLast("[OPEN]".count)).trimmingCharacters(in: .whitespaces)
        } else if finalTitle.hasSuffix("[IN_PROGRESS]") {
            status = .inProgress
            finalTitle = String(finalTitle.dropLast("[IN_PROGRESS]".count)).trimmingCharacters(in: .whitespaces)
        } else if finalTitle.hasSuffix("[CLOSED]") {
            status = .closed
            finalTitle = String(finalTitle.dropLast("[CLOSED]".count)).trimmingCharacters(in: .whitespaces)
        }

        return Issue(
            id: id,
            title: finalTitle,
            description: "",
            issueType: issueType,
            status: status,
            priority: priority,
            deps: []
        )
    }

    /// Parse `pb version` output.
    func parseVersion(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Handle "pebbles v0.8.0" format — extract version part
        if trimmed.lowercased().hasPrefix("pebbles ") {
            return String(trimmed.dropFirst("pebbles ".count))
        }
        return trimmed
    }

    // MARK: - Private Helpers

    /// Measure the logical depth of a tree line by counting box-drawing indentation.
    private func measureDepth(_ line: String) -> Int {
        var depth = 0
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "├" || ch == "└" {
                depth += 1
                break
            } else if ch == "│" || ch == " " {
                // Part of indentation
                i = line.index(after: i)
                continue
            } else {
                break
            }
        }
        // Count groups of 4 chars (│   or    ) before the branch char
        let prefix = String(line[line.startIndex..<i])
        let groupCount = prefix.count / 4
        return depth == 0 ? 0 : groupCount + 1
    }

    /// Remove box-drawing characters from a tree line.
    private func cleanTreeLine(_ line: String) -> String {
        var result = line
        let treeChars: [Character] = ["├", "└", "─", "│", "┬", "┤", "┌", "┐", "┘"]
        for ch in treeChars {
            result = result.replacingOccurrences(of: String(ch), with: "")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Recursively build a DepNode tree from a flat list of (depth, issue) pairs.
    private func buildTree(
        from nodes: [(depth: Int, issue: Issue)],
        index: Int,
        parentDepth: Int
    ) -> (node: DepNode?, nextIndex: Int) {
        guard index < nodes.count else { return (nil, index) }

        let (depth, issue) = nodes[index]
        guard depth > parentDepth else { return (nil, index) }

        var children: [DepNode] = []
        var currentIndex = index + 1

        while currentIndex < nodes.count {
            let childDepth = nodes[currentIndex].depth
            if childDepth <= depth { break }

            let result = buildTree(from: nodes, index: currentIndex, parentDepth: depth)
            if let childNode = result.node {
                children.append(childNode)
            }
            currentIndex = result.nextIndex
        }

        return (DepNode(issue: issue, dependencies: children), currentIndex)
    }
}
