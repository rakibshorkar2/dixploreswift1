import Foundation

enum DownloadStatus: String, Codable {
    case pending, downloading, paused, completed, failed
}

struct DownloadTaskItem: Identifiable, Codable {
    let id = UUID()
    let url: URL
    let filename: String
    var status: DownloadStatus
    var progress: Double
    var totalBytes: Int64
    var downloadedBytes: Int64
    var startDate: Date?
    var resumeData: Data?

    enum CodingKeys: String, CodingKey {
        case url, filename, status, progress, totalBytes, downloadedBytes, startDate
    }
}
