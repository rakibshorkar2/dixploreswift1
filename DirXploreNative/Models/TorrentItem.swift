import Foundation

enum TorrentStatus: String, Codable, Sendable {
    case downloading, seeding, paused, completed, error
}

struct TorrentItem: Identifiable, Codable, Sendable, Hashable {
    let id: String
    var name: String
    var hash: String
    var magnetLink: String
    var savePath: String
    var status: TorrentStatus
    var progress: Double
    var size: Int64
    var speed: Double
    var addedAt: Date
    var isSequential: Bool
    var files: [TorrentFileInfo]?
    var peers: [TorrentPeerInfo]?
    var trackers: [String]?

    var progressPercent: Int { Int(progress * 100) }

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var speedFormatted: String {
        if speed < 1024 { return "\(Int(speed)) B/s" }
        if speed < 1024 * 1024 { return String(format: "%.1f KB/s", speed / 1024) }
        return String(format: "%.1f MB/s", speed / (1024 * 1024))
    }
}

struct TorrentFileInfo: Codable, Sendable, Hashable {
    var path: String
    var size: Int64
    var selected: Bool
}

struct TorrentPeerInfo: Codable, Sendable, Hashable {
    var ip: String
    var port: Int
    var client: String
    var progress: Double
    var downloadSpeed: Double
    var uploadSpeed: Double
}

struct TorrentSearchResult: Identifiable, Codable, Sendable {
    var id: String { "\(provider)-\(title)" }
    var provider: String
    var title: String
    var magnetLink: String
    var seeders: Int
    var leechers: Int
    var size: String
    var category: String
    var uploadDate: String
}
