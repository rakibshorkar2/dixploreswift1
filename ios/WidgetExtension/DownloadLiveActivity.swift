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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.fileName)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(.white)
                        if !context.state.isCompleted {
                            Text(context.state.speed)
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.isCompleted ? "Done" : "\(Int(context.state.progress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        if !context.state.isCompleted {
                            Text(context.state.eta)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 2) {
                        ProgressView(value: context.state.isCompleted ? 1.0 : context.state.progress)
                            .tint(context.state.isCompleted ? .green : .blue)
                        HStack {
                            Text(context.state.speed)
                                .font(.caption2)
                                .foregroundColor(.green)
                            Spacer()
                            Text(context.state.eta)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isCompleted ? "checkmark.circle.fill" : "arrow.down.circle")
                    .foregroundColor(context.state.isCompleted ? .green : .blue)
            } compactTrailing: {
                Text(context.state.isCompleted ? "Done" : "\(Int(context.state.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            } minimal: {
                Image(systemName: context.state.isCompleted ? "checkmark.circle.fill" : "arrow.down.circle")
                    .foregroundColor(context.state.isCompleted ? .green : .blue)
            }
        }
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
                if context.state.isCompleted {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.blue)
                        Text(context.state.speed)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.state.isCompleted
                    ? "Done"
                    : "\(Int(context.state.progress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                if !context.state.isCompleted {
                    Text(context.state.eta)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.2))
        .activitySystemActionForegroundColor(.blue)
    }
}
