import Foundation

class StorageService {
    static let shared = StorageService()

    private let fileManager = FileManager.default

    var appDocumentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    var downloadsDirectory: URL {
        let dir = appDocumentsDirectory.appendingPathComponent("Downloads", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    var totalDiskSpace: Int64 {
        let path = appDocumentsDirectory.path
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: path) else { return 0 }
        return attrs[.systemSize] as? Int64 ?? 0
    }

    var freeDiskSpace: Int64 {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if #available(iOS 16.0, *) {
            if let capacity = try? url.resourceValues(forKeys: Set([.volumeAvailableCapacityForImportantUsageKey])).volumeAvailableCapacityForImportantUsage {
                return capacity
            }
        }
        let path = appDocumentsDirectory.path
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: path) else { return 0 }
        return attrs[.systemFreeSize] as? Int64 ?? 0
    }

    var usedDiskSpace: Int64 {
        totalDiskSpace - freeDiskSpace
    }

    func saveDownloadedFile(from sourceURL: URL, filename: String) -> URL? {
        let destURL = downloadsDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: destURL)
        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
        } catch {
            try? fileManager.moveItem(at: sourceURL, to: destURL)
        }
        return destURL
    }

    func deleteFile(at url: URL) -> Bool {
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    func fileExists(filename: String) -> Bool {
        let url = downloadsDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path)
    }

    func allDownloadedFiles() -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: downloadsDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        ) else { return [] }
        return urls
    }

    func ensureDownloadsDirectory() {
        _ = downloadsDirectory
    }
}
