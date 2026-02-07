# PebbleVision

A native macOS GUI for the [pebbles (`pb`)](https://github.com/Martian-Engineering/pebbles) issue tracker. Built with SwiftUI, PebbleVision wraps the `pb` CLI to provide a visual interface for browsing, creating, and managing issues across your projects.

## Features

- **Three-column layout** — project sidebar, issue list, and detail pane in a NavigationSplitView
- **Full issue management** — create, edit, and update issues with inline forms
- **Filtering and search** — filter by status, priority, type, and assignee; full-text search across issues
- **Dependency tree** — visualize issue dependencies in a hierarchical tree view
- **Event log** — browse the project event timeline with filtering
- **Ready view** — see which issues are unblocked and ready to work on
- **Worker info** — view claude-team worker assignments and git activity per issue
- **Priority, status, and type badges** — color-coded visual indicators throughout
- **Multi-project support** — switch between pebbles projects via the sidebar
- **Settings** — configure the `pb` binary path and default project

## Requirements

- macOS 14.0+ (Sonoma)
- Swift 5.9+
- [pebbles (`pb`)](https://github.com/Martian-Engineering/pebbles) CLI installed and available in PATH

## Building

### Swift Package Manager

```bash
cd PebbleVision
swift build
```

For a release build:

```bash
cd PebbleVision
swift build -c release
```

### Xcode

Open `PebbleVision/PebbleVision.xcodeproj` in Xcode 16+ and build the PebbleVision scheme.

### Install

After a release build, copy the binary into an app bundle:

```bash
cp PebbleVision/.build/arm64-apple-macosx/release/PebbleVision \
   /Applications/PebbleVision.app/Contents/MacOS/PebbleVision
```

## Architecture

PebbleVision follows an MVVM + Services pattern:

```
PebbleVision/PebbleVision/
  App/            # App entry point, ContentView, AppState
  Models/         # Issue, Event, Project, Dependency, etc.
  ViewModels/     # IssueListViewModel, IssueDetailViewModel, etc.
  Views/          # SwiftUI views organized by feature
  Services/       # PBClient (CLI wrapper), PBJSONParser, ProjectStore
  Utilities/      # ProcessRunner, DateFormatting
```

The app shells out to the `pb` CLI via `Foundation.Process` (through `PBClient`) and parses the JSON output into Swift models. There are no external dependencies beyond Apple frameworks.

## Usage

1. Install the `pb` CLI
2. Initialize a pebbles project: `pb init`
3. Launch PebbleVision and select your project directory
4. Browse, create, and manage issues from the GUI

## CI

A GitHub Actions workflow (`.github/workflows/build.yml`) runs on pushes to main — it builds a release binary, runs tests, and uploads the app bundle as an artifact.

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.
