import Foundation
import SwiftData

@MainActor
enum DatabaseProvider {
    static let shared = DatabaseProvider()

    private let container: ModelContainer

    private init() {
        let schema = Schema([
            DownloadEntity.self,
            TorrentEntity.self,
            BookmarkEntity.self,
            ProxyEntity.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var context: ModelContext {
        container.mainContext
    }

    func newContext() -> ModelContext {
        ModelContext(container)
    }
}

@Model
final class DownloadEntity {
    var id: String
    var url: String
    var fileName: String
    var savePath: String
    var batchId: String?
    var batchName: String?
    var statusRaw: String
    var totalBytes: Int64
    var downloadedBytes: Int64
    var speedBytesPerSec: Double
    var etaSeconds: Double
    var retryCount: Int
    var errorMessage: String?
    var addedAt: Date

    init(id: String, url: String, fileName: String, savePath: String, batchId: String? = nil, batchName: String? = nil, status: DownloadStatus = .queued, totalBytes: Int64 = 0, downloadedBytes: Int64 = 0, speedBytesPerSec: Double = 0, etaSeconds: Double = 0, retryCount: Int = 0, errorMessage: String? = nil, addedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.savePath = savePath
        self.batchId = batchId
        self.batchName = batchName
        self.statusRaw = status.rawValue
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.speedBytesPerSec = speedBytesPerSec
        self.etaSeconds = etaSeconds
        self.retryCount = retryCount
        self.errorMessage = errorMessage
        self.addedAt = addedAt
    }

    var status: DownloadStatus {
        get { DownloadStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class TorrentEntity {
    var id: String
    var name: String
    var hashValue: String
    var magnetLink: String
    var savePath: String
    var statusRaw: String
    var progress: Double
    var size: Int64
    var speed: Double
    var addedAt: Date
    var isSequential: Bool

    init(id: String, name: String, hashValue: String, magnetLink: String, savePath: String, status: TorrentStatus = .downloading, progress: Double = 0, size: Int64 = 0, speed: Double = 0, addedAt: Date = Date(), isSequential: Bool = false) {
        self.id = id
        self.name = name
        self.hashValue = hashValue
        self.magnetLink = magnetLink
        self.savePath = savePath
        self.statusRaw = status.rawValue
        self.progress = progress
        self.size = size
        self.speed = speed
        self.addedAt = addedAt
        self.isSequential = isSequential
    }

    var status: TorrentStatus {
        get { TorrentStatus(rawValue: statusRaw) ?? .downloading }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class BookmarkEntity {
    var id: String
    var name: String
    var url: String
    var addedAt: Date

    init(id: String = UUID().uuidString, name: String, url: String, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.url = url
        self.addedAt = addedAt
    }
}

@Model
final class ProxyEntity {
    var id: String
    var protocolRaw: String
    var host: String
    var port: Int
    var username: String
    var password: String
    var isActive: Bool
    var latencyMs: Double?

    init(id: String = UUID().uuidString, protocolType: ProxyProtocol, host: String, port: Int, username: String = "", password: String = "", isActive: Bool = false) {
        self.id = id
        self.protocolRaw = protocolType.rawValue
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.isActive = isActive
        self.latencyMs = nil
    }

    var protocolType: ProxyProtocol {
        get { ProxyProtocol(rawValue: protocolRaw) ?? .socks5 }
        set { protocolRaw = newValue.rawValue }
    }
}
