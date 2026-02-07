import Foundation

/// Shared date formatters for PebbleVision.
enum DateFormatting {
    /// ISO 8601 formatter for decoding RFC3339 timestamps from pb JSON output.
    /// Handles fractional seconds.
    static let rfc3339Decoder: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// ISO 8601 formatter without fractional seconds (fallback).
    static let rfc3339DecoderNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Display formatter for UI (e.g. "Jan 20, 2025 10:30 AM").
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Relative formatter (e.g. "2 hours ago", "yesterday").
    static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    /// Parse a date string from pb JSON output, trying fractional seconds first.
    static func parseDate(_ string: String) -> Date? {
        if let date = rfc3339Decoder.date(from: string) {
            return date
        }
        return rfc3339DecoderNoFraction.date(from: string)
    }

    /// Format a date for display in the UI.
    static func display(_ date: Date) -> String {
        displayFormatter.string(from: date)
    }

    /// Format a date as a relative string.
    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
