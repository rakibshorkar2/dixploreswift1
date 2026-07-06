import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct DownloadLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.fileName)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(.white)
                        Text(context.state.status)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.totalBytes > 0
                        ? "\(Int(context.state.progress * 100))%"
                        : "...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        ProgressView(value: context.state.progress)
                            .tint(.blue)
                        if context.state.totalBytes > 0 {
                            Text("\(formatBytes(context.state.receivedBytes)) / \(formatBytes(context.state.totalBytes))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                compactLeadingView(context: context)
            } compactTrailing: {
                compactTrailingView(context: context)
            } minimal: {
                minimalView(context: context)
            }
        }
    }

    private func compactLeadingView(context: ActivityViewContext<DownloadActivityAttributes>) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.circle")
                .foregroundColor(.blue)
            Text(context.state.totalBytes > 0
                ? "\(Int(context.state.progress * 100))%"
                : "...")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }

    private func compactTrailingView(context: ActivityViewContext<DownloadActivityAttributes>) -> some View {
        Text(context.state.status)
            .font(.caption2)
            .lineLimit(1)
            .foregroundColor(.secondary)
    }

    private func minimalView(context: ActivityViewContext<DownloadActivityAttributes>) -> some View {
        Image(systemName: "arrow.down.circle")
            .foregroundColor(.blue)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
    }
}

@available(iOS 16.1, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<DownloadActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.fileName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                    Text(context.state.status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.state.totalBytes > 0
                    ? "\(Int(context.state.progress * 100))%"
                    : "...")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(context.state.totalBytes > 0
                    ? "\(formatBytes(context.state.receivedBytes)) / \(formatBytes(context.state.totalBytes))"
                    : formatBytes(context.state.receivedBytes))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.2))
        .activitySystemActionForegroundColor(.blue)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
    }
}
