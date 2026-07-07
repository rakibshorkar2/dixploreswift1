import Foundation

enum DownloadStatus: String, Codable, Sendable {
    case queued, downloading, paused, error, done

    var label: String {
        switch self {
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .error: return "Error"
        case .done: return "Done"
        }
    }
}

struct DownloadItem: Identifiable, Codable, Sendable, Hashable {
    let id: String
    var url: String
    var fileName: String
    var savePath: String
    var batchId: String?
    var batchName: String?
    var status: DownloadStatus
    var totalBytes: Int64
    var downloadedBytes: Int64
    var speedBytesPerSec: Double
    var etaSeconds: TimeInterval
    var retryCount: Int
    var errorMessage: String?
    var addedAt: Date

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(downloadedBytes) / Double(totalBytes), 0), 1)
    }

    var progressPercent: Int {
        Int(progress * 100)
    }
}

extension DownloadItem {
    func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var totalSizeFormatted: String { formattedSize(totalBytes) }
    var downloadedFormatted: String { formattedSize(downloadedBytes) }

    var speedFormatted: String {
        if speedBytesPerSec < 1024 { return "\(Int(speedBytesPerSec)) B/s" }
        if speedBytesPerSec < 1024 * 1024 { return String(format: "%.1f KB/s", speedBytesPerSec / 1024) }
        return String(format: "%.1f MB/s", speedBytesPerSec / (1024 * 1024))
    }

    var etaFormatted: String {
        guard etaSeconds > 0, etaSeconds < .greatestFiniteMagnitude else { return "--" }
        if etaSeconds < 60 { return "\(Int(etaSeconds))s" }
        if etaSeconds < 3600 { return "\(Int(etaSeconds / 60))m \(Int(etaSeconds.truncatingRemainder(dividingBy: 60)))s" }
        let hours = Int(etaSeconds / 3600)
        let mins = Int((etaSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(mins)m"
    }
}
