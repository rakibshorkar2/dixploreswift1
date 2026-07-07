import Foundation
import Combine

@Observable
@MainActor
final class LibTorrentSessionManager: NSObject {
    static let shared = LibTorrentSessionManager()

    private var session: Session?
    private var isSessionActive = false

    var activeHandles: [String: TorrentHandle] = [:]
    var handleSnapshots: [String: TorrentHandle.Snapshot?] = [:]

    private override init() {
        super.init()
    }

    func initialize() {
        guard !isSessionActive else { return }
        isSessionActive = true

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let downloadPath = docs.appendingPathComponent("DirXplore/Downloads", isDirectory: true)
        let torrentsPath = docs.appendingPathComponent("DirXplore/Torrents", isDirectory: true)
        let fastResumePath = docs.appendingPathComponent("DirXplore/FastResume", isDirectory: true)

        try? FileManager.default.createDirectory(at: downloadPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: torrentsPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: fastResumePath, withIntermediateDirectories: true)

        let settings = SessionSettings()
        settings.agentName = "DirXplore/1.0"
        settings.maxActiveTorrents = 10
        settings.maxDownloadingTorrents = 5
        settings.maxUploadingTorrents = 3
        settings.maxDownloadSpeed = 0
        settings.maxUploadSpeed = 0
        settings.isDhtEnabled = true
        settings.isLsdEnabled = true
        settings.isUtpEnabled = true
        settings.isUpnpEnabled = true
        settings.isNatEnabled = true
        settings.encryptionPolicy = .enabled
        settings.validateHttpsTrackers = true
        settings.port = 6881
        settings.portBindRetries = 10

        let storages: [UUID: StorageModel] = [:]

        session = Session(
            with: downloadPath,
            torrentsPath: torrentsPath,
            fastResumePath: fastResumePath,
            settings: settings,
            storages: storages
        )
        session?.addDelegate(self)
        AppLogger.info("LibTorrent session initialized", category: AppLogger.torrent)
    }

    @discardableResult
    func addMagnet(_ magnetURL: URL) -> TorrentHandle? {
        guard let session else {
            AppLogger.error("Session not initialized", category: AppLogger.torrent)
            return nil
        }
        guard let magnet = MagnetURI(with: magnetURL) else {
            AppLogger.error("Invalid magnet URI", category: AppLogger.torrent)
            return nil
        }
        let handle = session.addTorrent(magnet)
        if let handle {
            let hash = hexString(from: handle.infoHashes.best)
            activeHandles[hash] = handle
            handle.updateSnapshot()
            handleSnapshots[hash] = handle.snapshot
            AppLogger.info("Added magnet torrent", category: AppLogger.torrent)
        }
        return handle
    }

    @discardableResult
    func addTorrentFile(_ url: URL) -> TorrentHandle? {
        guard let session else { return nil }
        guard let file = TorrentFile(with: url), file.isValid else { return nil }
        let handle = session.addTorrent(file)
        if let handle {
            let hash = hexString(from: handle.infoHashes.best)
            activeHandles[hash] = handle
            handle.updateSnapshot()
            handleSnapshots[hash] = handle.snapshot
        }
        return handle
    }

    func pauseTorrent(hash: String) {
        activeHandles[hash]?.pause()
    }

    func resumeTorrent(hash: String) {
        activeHandles[hash]?.resume()
    }

    func removeTorrent(hash: String, deleteFiles: Bool = false) {
        guard let session, let handle = activeHandles[hash] else { return }
        session.removeTorrent(handle, deleteFiles: deleteFiles)
        activeHandles.removeValue(forKey: hash)
        handleSnapshots.removeValue(forKey: hash)
    }

    func setSequentialDownload(hash: String, enabled: Bool) {
        activeHandles[hash]?.setSequentialDownload(enabled)
    }

    func setFilePriority(hash: String, fileIndex: Int, priority: FileEntry.Priority) {
        activeHandles[hash]?.setFilePriority(priority, at: fileIndex)
    }

    func addTracker(hash: String, url: String) {
        activeHandles[hash]?.addTracker(url)
    }

    func reannounce(hash: String) {
        activeHandles[hash]?.forceReannounce()
    }

    func pauseAll() {
        session?.pause()
    }

    func resumeAll() {
        session?.resume()
    }

    func updateSnapshots() {
        for (hash, handle) in activeHandles {
            handle.updateSnapshot()
            handleSnapshots[hash] = handle.snapshot
        }
    }

    func hashForHandle(_ handle: TorrentHandle) -> String {
        hexString(from: handle.infoHashes.best)
    }

    private func hexString(from data: Data?) -> String {
        guard let data else { return "" }
        return data.map { String(format: "%02x", $0) }.joined()
    }
}

extension LibTorrentSessionManager: SessionDelegate {
    func torrentManager(_ manager: Session, didAdd torrent: TorrentHandle) {
        let hash = hexString(from: torrent.infoHashes.best)
        activeHandles[hash] = torrent
        torrent.updateSnapshot()
        handleSnapshots[hash] = torrent.snapshot
        AppLogger.info("Torrent added via delegate", category: AppLogger.torrent)
    }

    func torrentManager(_ manager: Session, didRemoveTorrentWith hashesData: TorrentHashes) {
        let hash = hexString(from: hashesData.best)
        activeHandles.removeValue(forKey: hash)
        handleSnapshots.removeValue(forKey: hash)
        AppLogger.info("Torrent removed via delegate", category: AppLogger.torrent)
    }

    func torrentManager(_ manager: Session, didReceiveUpdateFor torrent: TorrentHandle) {
        torrent.updateSnapshot()
        let hash = hexString(from: torrent.infoHashes.best)
        handleSnapshots[hash] = torrent.snapshot
    }

    func torrentManager(_ manager: Session, didErrorOccur error: Error) {
        AppLogger.error("Session error: \(error.localizedDescription)", category: AppLogger.torrent)
    }
}

extension TorrentHandle.State {
    var toTorrentStatus: TorrentStatus {
        switch self {
        case .downloading: return .downloading
        case .seeding: return .seeding
        case .paused: return .paused
        case .finished: return .completed
        case .checkingFiles, .downloadingMetadata, .checkingResumeData, .storageError: return .downloading
        @unknown default: return .error
        }
    }
}

extension TorrentHandle.Snapshot {
    func toTorrentItem(hash: String, magnetLink: String, addedAt: Date) -> TorrentItem {
        TorrentItem(
            id: hash,
            name: name ?? "Unknown",
            hash: hash,
            magnetLink: magnetLink,
            savePath: downloadPath?.path ?? "",
            status: state.toTorrentStatus,
            progress: progress,
            size: Int64(total),
            speed: Double(downloadRate),
            addedAt: addedAt,
            isSequential: isSequential,
            files: files.map { entry in
                TorrentFileInfo(
                    path: entry.path,
                    size: Int64(entry.size),
                    selected: entry.priority.rawValue > 0
                )
            },
            peers: [],
            trackers: trackers.map(\.trackerUrl)
        )
    }
}
