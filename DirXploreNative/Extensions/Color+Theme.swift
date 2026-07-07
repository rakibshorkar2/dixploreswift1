import SwiftUI

extension Color {
    static let appBackground = Color(.systemBackground)
    static let appSecondaryBackground = Color(.secondarySystemBackground)
    static let appTertiaryBackground = Color(.tertiarySystemBackground)
    static let appGroupedBackground = Color(.systemGroupedBackground)

    static let accent = Color.blue
    static let accentGreen = Color.green
    static let accentOrange = Color.orange
    static let accentRed = Color.red

    static let glassBackground = Color(.systemBackground).opacity(0.7)
    static let glassBorder = Color(.separator).opacity(0.3)

    static let progressTrack = Color(.systemGray5)
    static let progressDownload = Color.blue
    static let progressPaused = Color.orange
    static let progressError = Color.red
    static let progressDone = Color.green

    static let downloadRate = Color.green
    static let downloadStatus = Color.secondary

    static let amoledBlack = Color(red: 0, green: 0, blue: 0)
    static let amoledSurface = Color(red: 0.05, green: 0.05, blue: 0.05)

    static let latencyGood = Color.green
    static let latencySlow = Color.orange
    static let latencyBad = Color.red

    static func iconColor(for status: String, isCompleted: Bool) -> Color {
        if isCompleted { return .green }
        switch status.lowercased() {
        case "downloading": return .blue
        case "paused": return .orange
        case "error", "failed": return .red
        case "queued": return .gray
        default: return .blue
        }
    }

    static func sfSymbol(for status: String, isCompleted: Bool) -> String {
        if isCompleted { return "checkmark.circle.fill" }
        switch status.lowercased() {
        case "downloading": return "arrow.down.circle.fill"
        case "paused": return "pause.circle.fill"
        case "error", "failed": return "exclamationmark.circle.fill"
        case "queued": return "clock.fill"
        default: return "arrow.down.circle"
        }
    }
}
