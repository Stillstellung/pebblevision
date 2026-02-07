import Foundation

/// Low-level async wrapper around Foundation.Process for CLI execution.
actor ProcessRunner {
    struct Output: Sendable {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    private let timeoutSeconds: TimeInterval

    init(timeoutSeconds: TimeInterval = 30) {
        self.timeoutSeconds = timeoutSeconds
    }

    /// Execute a CLI command asynchronously.
    /// - Parameters:
    ///   - executable: Path to the executable (e.g. "/usr/local/bin/pb" or "pb")
    ///   - arguments: Command arguments
    ///   - workingDirectory: The repo directory to run in
    ///   - environment: Extra env vars merged with the process environment
    /// - Returns: Output containing stdout, stderr, and exit code
    func run(
        executable: String,
        arguments: [String] = [],
        workingDirectory: String,
        environment: [String: String] = [:]
    ) async throws -> Output {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable.hasPrefix("/") ? executable : "/usr/bin/env")
        if !executable.hasPrefix("/") {
            process.arguments = [executable] + arguments
        } else {
            process.arguments = arguments
        }
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Merge environment: start with current process env, add pb-specific vars, then caller's overrides.
        // .app bundles have a minimal PATH that won't include user-installed tools,
        // so we augment PATH with common locations where `pb` might live.
        var env = ProcessInfo.processInfo.environment
        let extraPaths = [
            "\(NSHomeDirectory())/.local/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(NSHomeDirectory())/go/bin",
            "\(NSHomeDirectory())/.cargo/bin",
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        env["NO_COLOR"] = "1"
        env["PB_PAGER"] = "cat"
        env["TERM"] = "dumb"
        for (key, value) in environment {
            env[key] = value
        }
        process.environment = env

        return try await withCheckedThrowingContinuation { continuation in
            let workItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }

            DispatchQueue.global().asyncAfter(
                deadline: .now() + self.timeoutSeconds,
                execute: workItem
            )

            do {
                try process.run()
            } catch {
                workItem.cancel()
                continuation.resume(throwing: PBError.pbNotFound(path: executable))
                return
            }

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()
            workItem.cancel()

            let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
            let exitCode = process.terminationStatus

            if process.terminationReason == .uncaughtSignal {
                continuation.resume(throwing: PBError.timeout)
                return
            }

            continuation.resume(returning: Output(
                stdout: stdoutStr,
                stderr: stderrStr,
                exitCode: exitCode
            ))
        }
    }
}
