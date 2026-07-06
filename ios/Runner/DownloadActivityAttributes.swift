import ActivityKit
import Foundation

struct DownloadActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var fileName: String
        var progress: Double
        var speed: String
        var eta: String
        var isCompleted: Bool
    }

    var downloadId: String
}
