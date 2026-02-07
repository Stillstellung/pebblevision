# pebbleVision Research: Pebbles CLI Reference

> Comprehensive reference for building a macOS SwiftUI GUI around the `pb` CLI tool.
> Source: [Martian-Engineering/pebbles](https://github.com/Martian-Engineering/pebbles) v0.8.0 (Feb 2026)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Data Model](#data-model)
3. [Event Format (events.jsonl)](#event-format)
4. [SQLite Schema](#sqlite-schema)
5. [Command Reference](#command-reference)
6. [Output Parsing Strategy](#output-parsing-strategy)
7. [Environment Variables](#environment-variables)
8. [GUI Design Considerations](#gui-design-considerations)

---

## Architecture Overview

Pebbles is a minimalist, offline-first issue tracker designed for git repositories. Core design:

- **Source of truth**: `.pebbles/events.jsonl` — append-only JSONL log
- **Derived cache**: `.pebbles/pebbles.db` — SQLite, rebuilt from events (never committed to git)
- **Config**: `.pebbles/config.json` — stores project prefix
- **Git-safe**: append-only log means merge = concatenate both sides (no conflicts)
- **Deterministic IDs**: `<prefix>-<hash>` format, based on project prefix + title hash + timestamp + hostname

The SQLite DB can be deleted safely — any `pb` command will rebuild it from the event log.

### Directory Layout

```
.pebbles/
├── events.jsonl    # Primary data (committed to git)
├── pebbles.db      # SQLite cache (gitignored)
└── config.json     # Project config {"prefix": "pb"}
```

The `PEBBLES_DIR` env var overrides the default `.pebbles` directory (useful for worktree workflows).

---

## Data Model

### Issue Fields

| Field       | Type     | Values / Notes |
|-------------|----------|----------------|
| id          | string   | `<prefix>-<suffix>`, e.g. `pb-a1b` — child issues: `<parent>.<N>` |
| title       | string   | Free text |
| description | string   | Free text (rendered as markdown by `pb show`) |
| issue_type  | string   | Free-form: `task`, `bug`, `feature`, `epic`, `chore`, etc. |
| status      | string   | `open`, `in_progress`, `closed` |
| priority    | int      | 0–4 (displayed as `P0`–`P4`; default `P2` if unspecified) |
| created_at  | datetime | RFC3339Nano |
| updated_at  | datetime | RFC3339Nano |
| closed_at   | datetime | RFC3339Nano (null if not closed) |

### Dependency Types

| Type           | Meaning |
|----------------|---------|
| `blocks`       | Default. `pb dep add A B` means "A depends on B" (B blocks A) |
| `parent-child` | Hierarchical. `pb dep add --type parent-child <child> <parent>` |

### Priority Colors (in CLI)

| Priority | Label | Color      |
|----------|-------|------------|
| P0       | P0    | Bold Red   |
| P1       | P1    | Magenta    |
| P2       | P2    | Yellow     |
| P3       | P3    | Blue       |
| P4       | P4    | Cyan       |

### Status Icons (in CLI)

| Status      | Icon | Color         |
|-------------|------|---------------|
| open        | ○    | (default)     |
| in_progress | ◐    | Bright Yellow |
| closed      | ●    | Bright Green  |

### Issue Type Colors (in CLI)

| Type    | Color      |
|---------|------------|
| bug     | Bright Red |
| epic    | Magenta    |
| feature | Blue       |
| chore   | Cyan       |

---

## Event Format

File: `.pebbles/events.jsonl` — one JSON object per line, append-only.

### Base Event Structure

```json
{
  "type": "<event_type>",
  "timestamp": "<RFC3339Nano>",
  "issue_id": "<issue-id>",
  "payload": { "<key>": "<value>", ... }
}
```

### Event Types and Payloads

#### `create`
```json
{
  "type": "create",
  "timestamp": "2025-01-20T10:30:00.000000000Z",
  "issue_id": "pb-a1b",
  "payload": {
    "title": "Fix login bug",
    "description": "Users can't log in with SSO",
    "type": "bug",
    "priority": "1"
  }
}
```

#### `title_updated`
```json
{
  "type": "title_updated",
  "timestamp": "...",
  "issue_id": "pb-a1b",
  "payload": {
    "title": "New title here"
  }
}
```

#### `status_update`
```json
{
  "type": "status_update",
  "timestamp": "...",
  "issue_id": "pb-a1b",
  "payload": {
    "status": "in_progress"
  }
}
```

#### `update`
Generic update — payload is a map of changed fields:
```json
{
  "type": "update",
  "timestamp": "...",
  "issue_id": "pb-a1b",
  "payload": {
    "type": "feature",
    "priority": "2",
    "description": "Updated description"
  }
}
```

#### `close`
```json
{
  "type": "close",
  "timestamp": "...",
  "issue_id": "pb-a1b",
  "payload": {}
}
```

#### `comment`
```json
{
  "type": "comment",
  "timestamp": "...",
  "issue_id": "pb-a1b",
  "payload": {
    "body": "This is a comment"
  }
}
```

#### `rename`
```json
{
  "type": "rename",
  "timestamp": "...",
  "issue_id": "pb-a1b",
  "payload": {
    "new_id": "pb-xyz"
  }
}
```

#### `dep_add`
```json
{
  "type": "dep_add",
  "timestamp": "...",
  "issue_id": "pb-a1b",
  "payload": {
    "depends_on": "pb-c3d",
    "dep_type": "blocks"
  }
}
```

#### `dep_rm`
```json
{
  "type": "dep_rm",
  "timestamp": "...",
  "issue_id": "pb-a1b",
  "payload": {
    "depends_on": "pb-c3d",
    "dep_type": "blocks"
  }
}
```

---

## SQLite Schema

Three tables in `.pebbles/pebbles.db`:

### `issues`
```sql
CREATE TABLE issues (
  id         TEXT PRIMARY KEY,
  title      TEXT,
  description TEXT,
  issue_type TEXT,
  status     TEXT,
  priority   INTEGER,
  created_at TEXT,
  updated_at TEXT,
  closed_at  TEXT
);
```

### `deps`
```sql
CREATE TABLE deps (
  issue_id      TEXT,
  depends_on_id TEXT,
  dep_type      TEXT,
  PRIMARY KEY (issue_id, depends_on_id, dep_type)
);
```

### `renames`
```sql
CREATE TABLE renames (
  old_id TEXT PRIMARY KEY,
  new_id TEXT
);
```

### Rebuild Process

The DB is rebuilt by replaying every event in `events.jsonl` in order:
1. `ensureSchema()` creates tables
2. Each event is dispatched to a handler (create → INSERT, status_update → UPDATE, etc.)
3. Renames update both `issues` and `deps` tables and record in `renames`
4. `resolveEventIssueID()` follows rename chains to find current ID

---

## Command Reference

> **Important**: Set `NO_COLOR=1` when calling `pb` programmatically to get clean, parseable output.

### `pb init`

Initialize a pebbles project in the current directory.

```
pb init [--prefix <name>]
```

| Flag | Description |
|------|-------------|
| `--prefix` | Set project ID prefix (default: directory name based) |

**Output**: Creates `.pebbles/` directory. No stdout on success.
**Errors**: Exits 1 if already initialized.

---

### `pb create`

Create a new issue.

```
pb create --title "..." [--type <type>] [--priority <P0-P4>] [--description "..."]
```

| Flag | Required | Description |
|------|----------|-------------|
| `--title` | Yes | Issue title |
| `--type` | No | Issue type (task, bug, feature, epic, chore, etc.) |
| `--priority` | No | P0–P4 or 0–4 (default: P2) |
| `--description` | No | Longer description text |

**Output (stdout)**: The generated issue ID only, e.g.:
```
pb-a1b
```

**JSON**: Not available for create (just returns the ID string).
**Errors**: Exits 1 if `--title` is missing or project not initialized.

**Parsing strategy**: Read single line from stdout = the new issue ID.

---

### `pb list`

List issues with optional filtering.

```
pb list [--status <statuses>] [--type <types>] [--priority <priorities>]
        [--stale] [--stale-days N] [--all] [--json]
```

| Flag | Description |
|------|-------------|
| `--status` | Comma-separated: `open`, `in_progress`, `closed` (hyphens ok) |
| `--type` | Comma-separated type filter |
| `--priority` | Comma-separated: `P0`–`P4` or `0`–`4` |
| `--stale` | Show issues with no activity for 30+ days |
| `--stale-days N` | Override stale threshold |
| `--all` | Include closed issues (default: only open + in_progress) |
| `--json` | Output as JSON array |

**Default behavior** (v0.8.0+): Shows only `open` and `in_progress` issues. Use `--all` for closed.

**Text output format** (with `NO_COLOR=1`):
```
○ pb-a1b  [● P1] [bug]     [2025-01-20] - Fix login bug
◐ pb-c3d  [● P2] [feature] [2025-01-21] - Add dark mode
  ○ pb-c3d.1  [● P3] [task] [2025-01-22] - Design dark theme
```

- Status icon first (○/◐/●)
- ID (right-padded for alignment)
- Priority badge `[● P<N>]`
- Type in brackets
- Date in brackets
- Dash separator
- Title
- Child issues indented with 2 spaces per depth level
- Blocked issues show blockers: `blocked by: pb-xyz, pb-abc`

**JSON output** (`--json`):
```json
[
  {
    "id": "pb-a1b",
    "title": "Fix login bug",
    "description": "Users can't log in with SSO",
    "issue_type": "bug",
    "status": "open",
    "priority": "P1",
    "created_at": "2025-01-20T10:30:00Z",
    "updated_at": "2025-01-20T10:30:00Z",
    "closed_at": "",
    "deps": []
  }
]
```

JSON fields: `id`, `title`, `description`, `issue_type`, `status`, `priority` (as label "P0"–"P4"), `created_at`, `updated_at`, `closed_at`, `deps` (array of issue IDs, never null — empty = `[]`).

**Parsing strategy**: Use `--json` for programmatic access. Parse JSON array of issue objects.

---

### `pb show`

Show detailed information about a single issue.

```
pb show <issue-id> [--json]
```

**Text output format** (with `NO_COLOR=1`):
```
○ pb-a1b - Fix login bug [● P1] OPEN
Type: bug
Parents: pb-epic1
Created: 2025-01-20 10:30:00
Updated: 2025-01-20 12:00:00

Description:
  Users can't log in with SSO. The OAuth callback URL is wrong.

Dependencies:
  ○ pb-xyz - Set up OAuth provider [OPEN]

Children:
  ○ pb-a1b.1 - Investigate SSO config [OPEN]
  ◐ pb-a1b.2 - Fix callback URL [IN_PROGRESS]

Comments:
  [2025-01-20 11:00:00]
  Confirmed this affects all SSO providers.

  [2025-01-20 12:00:00]
  Root cause identified in config.
```

Sections shown:
1. Header: status icon, ID, title, priority badge, status label
2. Metadata: type, parents, created/updated/closed timestamps
3. Description (rendered as markdown in terminal)
4. Dependencies with their status
5. Children (parent-child relationships)
6. Comments with timestamps

**JSON output** (`--json`):
```json
{
  "id": "pb-a1b",
  "title": "Fix login bug",
  "description": "Users can't log in with SSO",
  "issue_type": "bug",
  "status": "open",
  "priority": "P1",
  "created_at": "2025-01-20T10:30:00Z",
  "updated_at": "2025-01-20T12:00:00Z",
  "closed_at": "",
  "deps": ["pb-xyz"],
  "parents": ["pb-epic1"],
  "siblings": [],
  "children": ["pb-a1b.1", "pb-a1b.2"],
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
```

JSON adds: `parents`, `siblings`, `children` (all string arrays), `comments` (array of `{body, timestamp}`).

**Parsing strategy**: Use `--json` for full structured data including hierarchy and comments.

---

### `pb update`

Update an existing issue's properties.

```
pb update <issue-id> [--status <status>] [--title "..."] [--type <type>]
                     [--priority <P0-P4>] [--description "..."]
                     [--parent <id>|none]
```

| Flag | Description |
|------|-------------|
| `--status` | `open`, `in_progress`, `closed` |
| `--title` | New title (v0.8.0+) |
| `--type` | New issue type |
| `--priority` | P0–P4 or 0–4 |
| `--description` | New description |
| `--parent` | Set parent issue ID, or `none` to remove parent |

**Output**: No stdout on success. Errors to stderr with exit 1.
**JSON**: Not applicable.

**Note**: `--parent` triggers automatic child ID renaming (e.g., issue becomes `<parent>.<N>`).

**Parsing strategy**: Check exit code. 0 = success, 1 = error (read stderr).

---

### `pb close`

Close one or more issues.

```
pb close <issue-id> [<issue-id> ...]
```

Accepts multiple issue IDs (v0.7.0+).

**Output**: No stdout on success. Errors to stderr with exit 1.
**JSON**: Not applicable.

**Parsing strategy**: Check exit code.

---

### `pb reopen`

Reopen a closed issue.

```
pb reopen <issue-id>
```

**Output**: No stdout on success.
**JSON**: Not applicable.

**Parsing strategy**: Check exit code.

---

### `pb comment`

Add a comment to an issue.

```
pb comment <issue-id> --body "..."
```

| Flag | Required | Description |
|------|----------|-------------|
| `--body` | Yes | Comment text |

**Output**: No stdout on success. Errors to stderr with exit 1.
**JSON**: Not applicable.

**Parsing strategy**: Check exit code.

---

### `pb ready`

List issues that have no open blocking dependencies.

```
pb ready [--json]
```

**Text output**: Same format as `pb list` but filtered to unblocked issues only.

**JSON output** (`--json`): Same JSON array format as `pb list --json`.

**Parsing strategy**: Use `--json` for programmatic access.

---

### `pb dep add`

Create a dependency between two issues.

```
pb dep add [--type <dep-type>] <issue-a> <issue-b>
```

| Flag | Description |
|------|-------------|
| `--type` | `blocks` (default) or `parent-child` |

- `pb dep add A B` → A depends on B (B blocks A)
- `pb dep add --type parent-child <child> <parent>` → parent-child hierarchy

**Output**: No stdout on success. Errors to stderr with exit 1.

**Note**: For `parent-child`, the child issue gets renamed to `<parent>.<N>` format.

---

### `pb dep rm`

Remove a dependency.

```
pb dep rm <issue-a> <issue-b>
```

**Output**: No stdout on success.

---

### `pb dep tree`

Show dependency tree for an issue.

```
pb dep tree <issue-id>
```

**Text output**: Tree-formatted view of dependencies:
```
pb-epic1
├── pb-epic1.1 - Design phase [OPEN]
│   └── pb-epic1.2 - Implementation [OPEN]
└── pb-epic1.3 - Testing [OPEN]
```

**JSON**: Not documented as available for dep tree.

**Parsing strategy**: Parse tree characters or use `pb list --json` + `pb show --json` to reconstruct hierarchy.

---

### `pb log`

View event history.

```
pb log [--limit N] [--since <date>] [--until <date>]
       [--table] [--json] [--no-git] [--no-pager]
```

| Flag | Description |
|------|-------------|
| `--limit N` | Max events to show |
| `--since` | Start date (RFC3339 or YYYY-MM-DD) |
| `--until` | End date (RFC3339 or YYYY-MM-DD) |
| `--table` | Table format output |
| `--json` | JSON lines output |
| `--no-git` | Skip git blame actor lookup |
| `--no-pager` | Disable pagination (less) |

**Pretty format** (default):
```
#1 [create] pb-a1b
  Title:  Fix login bug
  When:   2025-01-20 10:30:00
  Actor:  Joel (2025-01-20)
  Details: type=bug priority=P1 description="Users can't..."
```

**Table format** (`--table`):
Fixed-width columns: Actor | ActorDate | EventTime | EventType | IssueID | IssueTitle | Details

**JSON format** (`--json`):
Line-delimited JSON (one object per line, NOT a JSON array):
```json
{"line":1,"timestamp":"2025-01-20T10:30:00Z","type":"create","label":"create","issue_id":"pb-a1b","issue_title":"Fix login bug","actor":"Joel","actor_date":"2025-01-20","details":"type=bug priority=P1","payload":{"title":"Fix login bug","type":"bug","priority":"1","description":"..."}}
```

Fields: `line`, `timestamp`, `type`, `label`, `issue_id`, `issue_title`, `actor`, `actor_date`, `details`, `payload` (raw event payload map).

**Parsing strategy**: Use `--json --no-pager --no-git` for fastest programmatic access. Each line is a separate JSON object. Use `--no-git` to skip slow git blame lookups.

---

### `pb rename`

Rename a single issue.

```
pb rename <old-id> <new-id>
```

**Output**: No stdout on success.

---

### `pb rename-prefix`

Batch rename issues to a new prefix.

```
pb rename-prefix --open <new-prefix>   # Only open issues
pb rename-prefix --full <new-prefix>   # All issues
```

**Output**: No stdout on success.

---

### `pb prefix set`

Update the project prefix for new issues.

```
pb prefix set <name>
```

**Output**: No stdout on success.

---

### `pb sync`

Commit events.jsonl to git (and optionally push).

```
pb sync [--push]
```

| Flag | Description |
|------|-------------|
| `--push` | Also push to remote after committing |

**Output**: Git output from commit/push operations.

Added in v0.7.0 for worktree visibility.

---

### `pb import beads`

Import issues from a Beads repository.

```
pb import beads --from <path> [--backup]
```

| Flag | Description |
|------|-------------|
| `--from` | Path to beads repository |
| `--backup` | Create backup before import |

---

### `pb version`

Display version info.

```
pb version
```

**Output**: Version string, e.g. `pebbles v0.8.0`

---

### `pb self-update`

Update the pb binary to latest version.

```
pb self-update
```

---

### `pb help`

Display help text.

```
pb help
pb <command> --help
```

---

## Output Parsing Strategy

### Recommended Approach for GUI

**Primary method: JSON output** via `--json` flag where available.

| Command | JSON Available | Parsing Method |
|---------|---------------|----------------|
| `pb list` | Yes (`--json`) | JSON array of issue objects |
| `pb show` | Yes (`--json`) | Single JSON object with hierarchy + comments |
| `pb ready` | Yes (`--json`) | JSON array (same format as list) |
| `pb log` | Yes (`--json`) | Line-delimited JSON (one object per line) |
| `pb create` | No | Single line = new issue ID |
| `pb update` | No | Exit code only (0 = success) |
| `pb close` | No | Exit code only |
| `pb reopen` | No | Exit code only |
| `pb comment` | No | Exit code only |
| `pb dep add/rm` | No | Exit code only |
| `pb dep tree` | No | Tree-formatted text |
| `pb version` | No | Single line string |

### Swift Process Execution Pattern

```swift
func runPB(_ args: [String], workingDirectory: URL) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/pb") // or find via `which pb`
    process.arguments = args
    process.currentDirectoryURL = workingDirectory
    process.environment = [
        "NO_COLOR": "1",
        "PB_PAGER": "cat",  // Disable pager
        "TERM": "dumb"
    ]
    // ... pipe stdout/stderr, run, return
}
```

### Key Environment Settings for GUI

```
NO_COLOR=1          # Disable ANSI escape codes
PB_NO_COLOR=1       # Alternative
PB_PAGER=cat        # Disable pager (or use --no-pager for log)
PEBBLES_DIR=<path>  # Override .pebbles directory location
```

### Direct File Access (Alternative to CLI)

The GUI could also read data directly:

1. **Read events.jsonl** — parse each line as JSON, replay to build state
2. **Read pebbles.db** — query SQLite directly for current state (faster for reads)
3. **Watch events.jsonl** — use FSEvents/kqueue to detect changes from external `pb` usage

**Hybrid approach (recommended)**:
- Use SQLite for fast reads (list, show, search)
- Use CLI for writes (create, update, close) — ensures proper event generation
- Watch events.jsonl for change detection and cache invalidation

### JSON Type Reference (Swift Codable)

```swift
struct PBIssue: Codable {
    let id: String
    let title: String
    let description: String
    let issueType: String      // JSON key: "issue_type"
    let status: String         // "open", "in_progress", "closed"
    let priority: String       // "P0"–"P4"
    let createdAt: String      // JSON key: "created_at"
    let updatedAt: String      // JSON key: "updated_at"
    let closedAt: String       // JSON key: "closed_at" (empty string if not closed)
    let deps: [String]         // Issue IDs (always present, never null)

    // Only present in `pb show --json`:
    let parents: [String]?
    let siblings: [String]?
    let children: [String]?
    let comments: [PBComment]?
}

struct PBComment: Codable {
    let body: String
    let timestamp: String
}

struct PBLogEntry: Codable {
    let line: Int
    let timestamp: String
    let type: String
    let label: String
    let issueId: String        // JSON key: "issue_id"
    let issueTitle: String     // JSON key: "issue_title"
    let actor: String
    let actorDate: String      // JSON key: "actor_date"
    let details: String
    let payload: [String: String]
}

struct PBEvent: Codable {
    let type: String
    let timestamp: String
    let issueId: String        // JSON key: "issue_id"
    let payload: [String: String]
}
```

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `NO_COLOR=1` | Disable ANSI color output |
| `PB_NO_COLOR=1` | Alternative color disable |
| `CLICOLOR=0` | Another way to disable color |
| `PB_PAGER` | Override pager command (set to `cat` to disable) |
| `PAGER` | Fallback pager (default: `less -FRX`) |
| `PEBBLES_DIR` | Override `.pebbles` directory path |

---

## GUI Design Considerations

### Edge Cases and Gotchas

1. **ID Renaming**: Issues can be renamed. The `renames` table tracks old→new mappings. After a rename, old IDs in the event log still work because `resolveEventIssueID()` follows the chain. The GUI should handle stale IDs gracefully.

2. **Parent-child auto-rename**: When `pb dep add --type parent-child child parent` is used, the child gets renamed to `<parent>.<N>`. The GUI should refresh after dependency changes.

3. **Priority as string vs int**: In JSON output, priority is a label (`"P0"`–`"P4"`). In SQLite and events, it's an integer (0–4). In event payloads, it's a string representation of the integer (`"1"`).

4. **Closed_at empty string**: In JSON output, `closed_at` is an empty string `""` (not null) when the issue is not closed.

5. **Deps never null**: The `deps` array in JSON is always `[]`, never `null`. Same for `parents`, `siblings`, `children` in show output.

6. **Multiple close**: `pb close` accepts multiple IDs since v0.7.0.

7. **Default list filter**: Since v0.8.0, `pb list` only shows open + in_progress. Use `--all` to include closed.

8. **Concurrent access**: Multiple processes can append to events.jsonl safely (append-only). The SQLite DB is rebuilt from events, so concurrent reads are safe. However, avoid concurrent CLI writes from the GUI + terminal simultaneously without coordination.

9. **Git blame for actors**: `pb log` uses `git blame` on events.jsonl to determine who made each change. This requires the repo to be a git repository. Use `--no-git` to skip this (faster, returns "unknown" for actor).

10. **Stale threshold**: The `--stale` flag defaults to 30 days of inactivity. Customizable with `--stale-days`.

11. **Description markdown**: `pb show` renders description as markdown using the glamour library. The raw text is stored in the event/DB — the GUI should render markdown itself.

12. **Issue type is free-form**: There's no fixed enum — users can use any string. Common values: `task`, `bug`, `feature`, `epic`, `chore`.

### Recommended Data Flow for GUI

```
                    ┌─────────────┐
                    │  GUI (Swift) │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        ┌─────▼─────┐ ┌───▼───┐ ┌─────▼─────┐
        │ Read:      │ │Write: │ │ Watch:     │
        │ SQLite DB  │ │pb CLI │ │ FSEvents   │
        │ (fast)     │ │       │ │ events.jsonl│
        └────────────┘ └───────┘ └────────────┘
```

1. **Reads**: Query `.pebbles/pebbles.db` directly via SQLite for fast list/show/search
2. **Writes**: Shell out to `pb create/update/close/comment/dep` to ensure proper event generation
3. **Watch**: Monitor `events.jsonl` for changes (FSEvents) to detect external edits and refresh
4. **Fallback**: If SQLite is stale/missing, run any `pb` command to trigger rebuild, or use `pb list --json`
