import ActivityKit
import Foundation

struct DownloadActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var fileName: String
        var receivedBytes: Int64
        var totalBytes: Int64
        var progress: Double
        var status: String
    }

    var downloadId: String
}
