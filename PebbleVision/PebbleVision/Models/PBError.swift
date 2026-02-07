import Foundation

/// Unified error type for PebbleVision.
enum PBError: LocalizedError, Equatable {
    case notInitialized(path: String)
    case issueNotFound(id: String)
    case commandFailed(stderr: String, exitCode: Int32)
    case parseError(detail: String)
    case pbNotFound(path: String)
    case timeout
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized(let path):
            "Project not initialized at \(path). Run 'pb init' first."
        case .issueNotFound(let id):
            "Issue '\(id)' not found."
        case .commandFailed(let stderr, let exitCode):
            "Command failed (exit \(exitCode)): \(stderr)"
        case .parseError(let detail):
            "Failed to parse output: \(detail)"
        case .pbNotFound(let path):
            "pb binary not found at '\(path)'."
        case .timeout:
            "Command timed out."
        case .unexpected(let msg):
            "Unexpected error: \(msg)"
        }
    }
}
