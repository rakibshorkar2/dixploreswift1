import Foundation
import Combine

@Observable
@MainActor
final class TorrentEngine {
    static let shared = TorrentEngine()

    var activeTorrents: [TorrentItem] = []
    var isInitialized = false

    private var timer: Timer?

    private init() {}

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        loadTorrents()
        startPolling()
    }

    func addMagnet(_ magnet: String, name: String? = nil) {
        guard let hash = extractHash(from: magnet) else {
            AppLogger.error("Invalid magnet link", category: AppLogger.torrent)
            return
        }

        let item = TorrentItem(
            id: hash,
            name: name ?? "Torrent \(hash.prefix(8))",
            hash: hash,
            magnetLink: magnet,
            savePath: defaultTorrentPath().path,
            status: .downloading,
            progress: 0,
            size: 0,
            speed: 0,
            addedAt: Date(),
            isSequential: false
        )

        activeTorrents.insert(item, at: 0)
        persistTorrents()
    }

    func pauseTorrent(id: String) {
        guard let index = activeTorrents.firstIndex(where: { $0.id == id }) else { return }
        activeTorrents[index].status = .paused
        persistTorrents()
    }

    func resumeTorrent(id: String) {
        guard let index = activeTorrents.firstIndex(where: { $0.id == id }) else { return }
        activeTorrents[index].status = .downloading
        persistTorrents()
    }

    func deleteTorrent(id: String) {
        activeTorrents.removeAll { $0.id == id }
        TorrentRepository.shared.delete(id: id)
    }

    func toggleSequential(id: String) {
        guard let index = activeTorrents.firstIndex(where: { $0.id == id }) else { return }
        activeTorrents[index].isSequential.toggle()
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

    private func loadTorrents() {
        let entities = TorrentRepository.shared.getAll()
        activeTorrents = entities.map { entity in
            TorrentItem(
                id: entity.id,
                name: entity.name,
                hash: entity.hashValue,
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
    }

    private func persistTorrents() {
        for item in activeTorrents {
            if let existing = TorrentRepository.shared.get(id: item.id) {
                existing.progress = item.progress
                existing.speed = item.speed
                existing.status = item.status
                TorrentRepository.shared.update(existing)
            } else {
                let entity = TorrentEntity(
                    id: item.id,
                    name: item.name,
                    hashValue: item.hash,
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
                self.persistTorrents()
            }
        }
    }
}
