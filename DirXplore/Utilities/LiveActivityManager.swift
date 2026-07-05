import Foundation
import ActivityKit

class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activities: [String: Activity<DownloadProgressAttributes>] = [:]

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func startDownloadActivity(id: String, filename: String) {
        guard areActivitiesEnabled else { return }

        let attributes = DownloadProgressAttributes(filename: filename)
        let state = DownloadProgressAttributes.ContentState(progress: 0, status: "downloading")
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            let activity = try Activity.request(attributes: attributes, content: content)
            activities[id] = activity
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateProgress(id: String, progress: Double) {
        Task {
            guard let activity = activities[id] else { return }
            let state = DownloadProgressAttributes.ContentState(progress: progress, status: "downloading")
            await activity.update(using: state)
        }
    }

    func endActivity(id: String, completed: Bool = true) {
        Task {
            guard let activity = activities[id] else { return }
            let state = DownloadProgressAttributes.ContentState(
                progress: completed ? 1.0 : 0,
                status: completed ? "completed" : "failed"
            )
            await activity.end(using: state, dismissalPolicy: .default)
            activities.removeValue(forKey: id)
        }
    }
}
