// GitCommit.swift
// PebbleVision

import Foundation

/// A git commit that references an issue.
struct GitCommit: Identifiable, Sendable {
    var id: String        // full SHA
    var shortSHA: String  // abbreviated
    var message: String
    var author: String
    var date: Date
}
