import Foundation
import Combine

@Observable
@MainActor
final class TorrentEngine {
    static let shared = TorrentEngine()

    var activeTorrents: [TorrentItem] = []
    var isInitialized = false

    private var timer: Timer?
    private let sessionManager = LibTorrentSessionManager.shared
    private var addedAtMap: [String: Date] = [:]
    private var magnetLinkMap: [String: String] = [:]

    private init() {}

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        sessionManager.initialize()
        loadTorrents()

        for torrent in activeTorrents {
            if !torrent.magnetLink.isEmpty {
                let url = URL(string: torrent.magnetLink)
                if let url, sessionManager.activeHandles[torrent.hash] == nil {
                    let handle = sessionManager.addMagnet(url)
                    if let handle {
                        addedAtMap[torrent.hash] = torrent.addedAt
                    }
                }
            }
        }

        startPolling()
        AppLogger.info("TorrentEngine initialized with LibTorrent", category: AppLogger.torrent)
    }

    func addMagnet(_ magnet: String, name: String? = nil) {
        guard let hash = extractHash(from: magnet) else {
            AppLogger.error("Invalid magnet link", category: AppLogger.torrent)
            return
        }

        guard let url = URL(string: magnet) else { return }

        if sessionManager.activeHandles[hash] != nil { return }

        let handle = sessionManager.addMagnet(url)
        let now = Date()

        addedAtMap[hash] = now
        magnetLinkMap[hash] = magnet

        let item: TorrentItem
        if let handle, let snapshot = handle.snapshot {
            item = snapshot.toTorrentItem(hash: hash, magnetLink: magnet, addedAt: now)
        } else {
            item = TorrentItem(
                id: hash,
                name: name ?? "Torrent \(hash.prefix(8))",
                hash: hash,
                magnetLink: magnet,
                savePath: defaultTorrentPath().path,
                status: .downloading,
                progress: 0,
                size: 0,
                speed: 0,
                addedAt: now,
                isSequential: false
            )
        }

        if !activeTorrents.contains(where: { $0.id == hash }) {
            activeTorrents.insert(item, at: 0)
        }
        persistTorrents()
    }

    func pauseTorrent(id: String) {
        sessionManager.pauseTorrent(hash: id)
        guard let index = activeTorrents.firstIndex(where: { $0.id == id }) else { return }
        activeTorrents[index].status = .paused
        persistTorrents()
    }

    func resumeTorrent(id: String) {
        sessionManager.resumeTorrent(hash: id)
        guard let index = activeTorrents.firstIndex(where: { $0.id == id }) else { return }
        activeTorrents[index].status = .downloading
        persistTorrents()
    }

    func deleteTorrent(id: String) {
        sessionManager.removeTorrent(hash: id, deleteFiles: false)
        activeTorrents.removeAll { $0.id == id }
        addedAtMap.removeValue(forKey: id)
        magnetLinkMap.removeValue(forKey: id)
        TorrentRepository.shared.delete(id: id)
    }

    func deleteTorrentWithFiles(id: String) {
        sessionManager.removeTorrent(hash: id, deleteFiles: true)
        activeTorrents.removeAll { $0.id == id }
        addedAtMap.removeValue(forKey: id)
        magnetLinkMap.removeValue(forKey: id)
        TorrentRepository.shared.delete(id: id)
    }

    func toggleSequential(id: String) {
        guard let index = activeTorrents.firstIndex(where: { $0.id == id }) else { return }
        activeTorrents[index].isSequential.toggle()
        sessionManager.setSequentialDownload(hash: id, enabled: activeTorrents[index].isSequential)
        persistTorrents()
    }

    func fetchMetadata(magnet: String) async -> TorrentItem? {
        let hash = extractHash(from: magnet)
        let name = extractName(from: magnet) ?? "Torrent \(hash?.prefix(8) ?? "unknown")"

        let resolved = TorrentItem(
            id: hash ?? magnet,
            name: name,
            hash: hash ?? magnet,
            magnetLink: magnet,
            savePath: defaultTorrentPath().path,
            status: .downloading,
            progress: 0,
            size: 0,
            speed: 0,
            addedAt: Date(),
            isSequential: false
        )
        return resolved
    }

    func setFilePriority(hash: String, fileIndex: Int, priority: UInt8) {
        let fp: FileEntry.Priority
        switch priority {
        case 0: fp = .dontDownload
        case 1: fp = .low
        case 7: fp = .top
        default: fp = .default
        }
        sessionManager.setFilePriority(hash: hash, fileIndex: fileIndex, priority: fp)
    }

    func addTracker(hash: String, url: String) {
        sessionManager.addTracker(hash: hash, url: url)
    }

    func reannounce(hash: String) {
        sessionManager.reannounce(hash: hash)
    }

    func pauseAll() {
        sessionManager.pauseAll()
        for i in activeTorrents.indices {
            activeTorrents[i].status = .paused
        }
        persistTorrents()
    }

    func resumeAll() {
        sessionManager.resumeAll()
        for i in activeTorrents.indices {
            if activeTorrents[i].status == .paused {
                activeTorrents[i].status = .downloading
            }
        }
        persistTorrents()
    }

    // MARK: - Private

    private func extractHash(from magnet: String) -> String? {
        guard magnet.hasPrefix("magnet:") else { return nil }
        guard let url = URLComponents(string: magnet) else { return nil }
        let btih = url.queryItems?.first(where: { $0.name == "xt" })?.value
        return btih?.replacingOccurrences(of: "urn:btih:", with: "").lowercased()
    }

    private func extractName(from magnet: String) -> String? {
        guard let url = URLComponents(string: magnet) else { return nil }
        let dn = url.queryItems?.first(where: { $0.name == "dn" })?.value
        return dn?.removingPercentEncoding
    }

    private func defaultTorrentPath() -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsDir.appendingPathComponent("DirXplore/Torrents", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func syncSnapshotsToItems() {
        sessionManager.updateSnapshots()

        for (hash, snapshot) in sessionManager.handleSnapshots {
            guard let snapshot, snapshot.isValid else { continue }

            let magnet = magnetLinkMap[hash] ?? snapshot.magnetLink
            let addedAt = addedAtMap[hash] ?? Date()

            if let index = activeTorrents.firstIndex(where: { $0.id == hash }) {
                activeTorrents[index].name = snapshot.name ?? activeTorrents[index].name
                activeTorrents[index].status = snapshot.state.toTorrentStatus
                activeTorrents[index].progress = snapshot.progress
                activeTorrents[index].size = Int64(snapshot.total)
                activeTorrents[index].speed = Double(snapshot.downloadRate)
                activeTorrents[index].isSequential = snapshot.isSequential
                activeTorrents[index].savePath = snapshot.downloadPath?.path ?? activeTorrents[index].savePath

                if snapshot.hasMetadata {
                    activeTorrents[index].files = snapshot.files.map { entry in
                        TorrentFileInfo(
                            path: entry.path,
                            size: Int64(entry.size),
                            selected: entry.priority.rawValue > 0
                        )
                    }
                    activeTorrents[index].trackers = snapshot.trackers.map(\.trackerUrl)
                }
            } else {
                let item = snapshot.toTorrentItem(hash: hash, magnetLink: magnet, addedAt: addedAt)
                addedAtMap[hash] = addedAt
                magnetLinkMap[hash] = magnet
                activeTorrents.append(item)
            }
        }
    }

    private func loadTorrents() {
        let entities = TorrentRepository.shared.getAll()
        activeTorrents = entities.map { entity in
            TorrentItem(
                id: entity.id,
                name: entity.name,
                hash: entity.torrentHashValue,
                magnetLink: entity.magnetLink,
                savePath: entity.savePath,
                status: entity.status,
                progress: entity.progress,
                size: entity.size,
                speed: entity.speed,
                addedAt: entity.addedAt,
                isSequential: entity.isSequential
            )
        }
        for torrent in activeTorrents {
            addedAtMap[torrent.id] = torrent.addedAt
            magnetLinkMap[torrent.id] = torrent.magnetLink
        }
    }

    private func persistTorrents() {
        for item in activeTorrents {
            if let existing = TorrentRepository.shared.get(id: item.id) {
                existing.progress = item.progress
                existing.speed = item.speed
                existing.status = item.status
                existing.size = item.size
                existing.name = item.name
                TorrentRepository.shared.update(existing)
            } else {
                let entity = TorrentEntity(
                    id: item.id,
                    name: item.name,
                    torrentHashValue: item.hash,
                    magnetLink: item.magnetLink,
                    savePath: item.savePath,
                    status: item.status,
                    progress: item.progress,
                    size: item.size,
                    speed: item.speed,
                    addedAt: item.addedAt,
                    isSequential: item.isSequential
                )
                TorrentRepository.shared.save(entity)
            }
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.syncSnapshotsToItems()
                self.persistTorrents()
            }
        }
    }
}
