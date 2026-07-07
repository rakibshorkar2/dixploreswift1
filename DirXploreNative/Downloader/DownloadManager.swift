import Foundation
import UIKit
import ActivityKit
import UserNotifications

@Observable
@MainActor
final class DownloadManager: NSObject {
    static let shared = DownloadManager()

    var downloads: [DownloadItem] = []
    var activeCount: Int = 0
    var totalDownloadedBytes: Int64 = 0

    private var backgroundSession: URLSession!
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var taskIdMap: [Int: String] = [:]
    private var progressMap: [String: (received: Int64, total: Int64)] = [:]
    private var resumeDataMap: [String: Data] = [:]
    private var saveDirMap: [String: String] = [:]
    private var retryCountMap: [String: Int] = [:]
    private var downloadUrlMap: [String: String] = [:]
    private var fileNameMap: [String: String] = [:]
    private var speedTracker: [String: [(timestamp: Date, bytes: Int64)]] = [:]
    private let maxRetries = AppConfiguration.maxRetriesDefault

    var proxyConfig: ProxyConfiguration?
    var liveActivityEnabled = true
    var backgroundCompletionHandler: (() -> Void)?

    private var liveActivity: Activity<DownloadActivityAttributes>?
    private var activeDownloadCount = 0

    private struct SpeedSample {
        let timestamp: Date
        let bytes: Int64
    }

    private override init() {
        super.init()
        backgroundSession = createSession()
        loadPersistedDownloads()
    }

    private func createSession() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: AppConfiguration.backgroundDownloadIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.allowsCellularAccess = true
        if #available(iOS 13.0, *) {
            config.allowsExpensiveNetworkAccess = true
            config.allowsConstrainedNetworkAccess = true
        }
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 604800
        config.timeoutIntervalForRequest = 30

        if let proxy = proxyConfig, proxy.enabled {
            var proxyDict: [String: Any]
            switch proxy.protocolType.lowercased() {
            case "socks5", "socks4":
                proxyDict = [
                    "SOCKSEnable": 1,
                    "SOCKSProxy": proxy.host,
                    "SOCKSPort": proxy.port,
                ]
                if !proxy.username.isEmpty {
                    proxyDict["SOCKSUser"] = proxy.username
                    proxyDict["SOCKSPassword"] = proxy.password
                }
            case "https":
                proxyDict = [
                    "HTTPSEnable": 1,
                    "HTTPSProxy": proxy.host,
                    "HTTPSPort": proxy.port,
                ]
                if !proxy.username.isEmpty {
                    proxyDict["HTTPSUser"] = proxy.username
                    proxyDict["HTTPSPassword"] = proxy.password
                }
            default:
                proxyDict = [
                    "HTTPEnable": 1,
                    "HTTPProxy": proxy.host,
                    "HTTPPort": proxy.port,
                ]
                if !proxy.username.isEmpty {
                    proxyDict["HTTPUser"] = proxy.username
                    proxyDict["HTTPPassword"] = proxy.password
                }
                proxyDict["HTTPSEnable"] = 1
                proxyDict["HTTPSProxy"] = proxy.host
                proxyDict["HTTPSPort"] = proxy.port
            }
            config.connectionProxyDictionary = proxyDict
        }

        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public API

    func addDownload(url: String, fileName: String, saveDir: String? = nil, batchId: String? = nil, batchName: String? = nil) -> String {
        if downloads.contains(where: { $0.url == url && $0.status != .done }) {
            AppLogger.info("Duplicate download prevented: \(url)", category: AppLogger.download)
            return downloads.first(where: { $0.url == url })!.id
        }

        guard hasEnoughDiskSpace(expectedSize: 0) else {
            AppLogger.error("Not enough disk space for download", category: AppLogger.download)
            return ""
        }

        let downloadId = UUID().uuidString
        let smartDir = resolveSaveDirectory(fileName: fileName, preferred: saveDir)
        saveDirMap[downloadId] = smartDir.path
        try? FileManager.default.createDirectory(at: smartDir, withIntermediateDirectories: true)
        let savePath = smartDir.appendingPathComponent(fileName).path

        let item = DownloadItem(
            id: downloadId,
            url: url,
            fileName: fileName,
            savePath: savePath,
            batchId: batchId,
            batchName: batchName,
            status: .queued,
            totalBytes: 0,
            downloadedBytes: 0,
            speedBytesPerSec: 0,
            etaSeconds: 0,
            retryCount: 0,
            addedAt: Date()
        )

        downloads.insert(item, at: 0)
        persistDownloads()
        startDownload(downloadId: downloadId)
        return downloadId
    }

    private func resolveSaveDirectory(fileName: String, preferred: String?) -> URL {
        if let dir = preferred { return URL(fileURLWithPath: dir) }
        guard AppSettings.shared.smartFolderRouting else { return defaultDownloadsPath() }

        let ext = (fileName as NSString).pathExtension.lowercased()
        let baseDir = defaultDownloadsPath()

        let videoExts = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v"]
        let audioExts = ["mp3", "wav", "flac", "aac", "ogg", "m4a"]
        let archiveExts = ["zip", "rar", "7z", "tar", "gz"]
        let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "svg"]
        let docExts = ["pdf", "doc", "docx", "xls", "xlsx", "txt"]

        var subfolder = "Other"
        if videoExts.contains(ext) { subfolder = "Videos" }
        else if audioExts.contains(ext) { subfolder = "Music" }
        else if archiveExts.contains(ext) { subfolder = "Archives" }
        else if ext == "ipa" || ext == "apk" { subfolder = "Apps" }
        else if imageExts.contains(ext) { subfolder = "Images" }
        else if docExts.contains(ext) { subfolder = "Documents" }
        else if videoExts.contains(ext) { subfolder = "Movies" }

        let smartDir = baseDir.appendingPathComponent(subfolder)
        try? FileManager.default.createDirectory(at: smartDir, withIntermediateDirectories: true)
        return smartDir
    }

    private func hasEnoughDiskSpace(expectedSize: Int64) -> Bool {
        let free = UIDevice.current.freeDiskSpace
        let minRequired: Int64 = 50 * 1024 * 1024
        return free > minRequired + expectedSize
    }

    func startDownload(downloadId: String) {
        guard let index = downloads.firstIndex(where: { $0.id == downloadId }) else { return }
        downloads[index].status = .downloading

        let url = downloads[index].url
        let fileName = downloads[index].fileName
        downloadUrlMap[downloadId] = url
        fileNameMap[downloadId] = fileName

        guard let downloadUrl = URL(string: url) else {
            downloads[index].status = .error
            downloads[index].errorMessage = "Invalid URL"
            return
        }

        if let resumeData = resumeDataMap[downloadId] {
            let task = backgroundSession.downloadTask(withResumeData: resumeData)
            task.taskDescription = "\(downloadId)|\(fileName)"
            activeTasks[downloadId] = task
            taskIdMap[task.taskIdentifier] = downloadId
            resumeDataMap.removeValue(forKey: downloadId)
            task.resume()
        } else {
            var request = URLRequest(url: downloadUrl)
            request.setValue(AppConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
            let task = backgroundSession.downloadTask(with: request)
            task.taskDescription = "\(downloadId)|\(fileName)"
            activeTasks[downloadId] = task
            taskIdMap[task.taskIdentifier] = downloadId
            progressMap[downloadId] = (0, 0)
            task.resume()
        }

        activeCount = activeTasks.count
        updateLiveActivity()
    }

    func pauseDownload(downloadId: String) {
        guard let task = activeTasks[downloadId] else {
            updateDownloadStatus(downloadId: downloadId, status: .paused)
            return
        }
        task.cancel { [weak self] possibleResumeData in
            Task { @MainActor in
                guard let self else { return }
                if let data = possibleResumeData {
                    self.resumeDataMap[downloadId] = data
                }
                self.activeTasks.removeValue(forKey: downloadId)
                self.taskIdMap.removeValue(forKey: task.taskIdentifier)
                self.updateDownloadStatus(downloadId: downloadId, status: .paused)
                self.activeCount = self.activeTasks.count
                self.updateLiveActivity()
            }
        }
    }

    func resumeDownload(downloadId: String) {
        guard let index = downloads.firstIndex(where: { $0.id == downloadId }) else { return }
        guard downloads[index].status == .paused else { return }
        startDownload(downloadId: downloadId)
    }

    func cancelDownload(downloadId: String) {
        activeTasks[downloadId]?.cancel()
        activeTasks.removeValue(forKey: downloadId)
        taskIdMap.removeValue(forKey: (activeTasks[downloadId]?.taskIdentifier ?? 0))
        resumeDataMap.removeValue(forKey: downloadId)
        progressMap.removeValue(forKey: downloadId)
        retryCountMap.removeValue(forKey: downloadId)
        speedTracker.removeValue(forKey: downloadId)
        downloadUrlMap.removeValue(forKey: downloadId)
        fileNameMap.removeValue(forKey: downloadId)

        updateDownloadStatus(downloadId: downloadId, status: .error)
        if let index = downloads.firstIndex(where: { $0.id == downloadId }) {
            downloads[index].errorMessage = "Cancelled"
        }
        activeCount = activeTasks.count
        updateLiveActivity()
    }

    func pauseAll() {
        let activeIds = activeTasks.keys
        for id in activeIds {
            pauseDownload(downloadId: id)
        }
    }

    func resumeAll() {
        let pausedIds = downloads.filter { $0.status == .paused }.map { $0.id }
        for id in pausedIds {
            resumeDownload(downloadId: id)
        }
    }

    func cancelAll() {
        let allIds = downloads.map { $0.id }
        for id in allIds {
            cancelDownload(downloadId: id)
        }
    }

    func clearCompleted() {
        downloads.removeAll { $0.status == .done }
        DownloadRepository.shared.deleteCompleted()
    }

    func clearAll() {
        cancelAll()
        downloads.removeAll()
        DownloadRepository.shared.deleteAll()
    }

    func deleteDownload(id: String, deleteFile: Bool = false) {
        if deleteFile, let item = downloads.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: item.savePath))
        }
        cancelDownload(downloadId: id)
        downloads.removeAll { $0.id == id }
        DownloadRepository.shared.delete(id: id)
    }

    func retryDownload(downloadId: String) {
        guard let index = downloads.firstIndex(where: { $0.id == downloadId }) else { return }
        downloads[index].status = .queued
        downloads[index].retryCount = 0
        downloads[index].errorMessage = nil
        startDownload(downloadId: downloadId)
    }

    // MARK: - Persistence

    private func loadPersistedDownloads() {
        let entities = DownloadRepository.shared.getAll()
        downloads = entities.map { entity in
            DownloadItem(
                id: entity.id,
                url: entity.url,
                fileName: entity.fileName,
                savePath: entity.savePath,
                batchId: entity.batchId,
                batchName: entity.batchName,
                status: entity.status,
                totalBytes: entity.totalBytes,
                downloadedBytes: entity.downloadedBytes,
                speedBytesPerSec: entity.speedBytesPerSec,
                etaSeconds: entity.etaSeconds,
                retryCount: entity.retryCount,
                errorMessage: entity.errorMessage,
                addedAt: entity.addedAt
            )
        }
    }

    private func persistDownloads() {
        for item in downloads {
            if let existing = DownloadRepository.shared.get(id: item.id) {
                existing.status = item.status
                existing.downloadedBytes = item.downloadedBytes
                existing.totalBytes = item.totalBytes
                existing.speedBytesPerSec = item.speedBytesPerSec
                existing.etaSeconds = item.etaSeconds
                existing.retryCount = item.retryCount
                existing.errorMessage = item.errorMessage
                DownloadRepository.shared.update(existing)
            } else {
                let entity = DownloadEntity(
                    id: item.id,
                    url: item.url,
                    fileName: item.fileName,
                    savePath: item.savePath,
                    batchId: item.batchId,
                    batchName: item.batchName,
                    status: item.status,
                    totalBytes: item.totalBytes,
                    downloadedBytes: item.downloadedBytes,
                    addedAt: item.addedAt
                )
                DownloadRepository.shared.save(entity)
            }
        }
    }

    // MARK: - Helpers

    private func defaultDownloadsDirectory() -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsDir.appendingPathComponent("DirXplore", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func updateDownloadStatus(downloadId: String, status: DownloadStatus) {
        guard let index = downloads.firstIndex(where: { $0.id == downloadId }) else { return }
        downloads[index].status = status
        persistDownloads()
    }

    private func calculateSpeed(downloadId: String, received: Int64) -> Double {
        let now = Date()
        if speedTracker[downloadId] == nil {
            speedTracker[downloadId] = []
        }
        speedTracker[downloadId]?.append((now, received))
        speedTracker[downloadId] = speedTracker[downloadId]?.filter { now.timeIntervalSince($0.timestamp) < 3 }

        guard let samples = speedTracker[downloadId], samples.count >= 2 else { return 0 }
        let oldestBytes = samples.first?.bytes ?? received
        let oldestTime = samples.first?.timestamp ?? now
        let bytesDelta = received - oldestBytes
        let timeDelta = now.timeIntervalSince(oldestTime)
        guard timeDelta > 0 else { return 0 }
        return Double(bytesDelta) / timeDelta
    }

    private func defaultDownloadsPath() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("DirXplore")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Live Activity

    private func updateLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        let previousCount = activeDownloadCount
        activeDownloadCount = activeTasks.count

        let primaryInfo = activeDownloadsPrimaryInfo()

        if activeDownloadCount > 0 {
            if previousCount == 0 {
                startLiveActivity(info: primaryInfo)
            } else {
                updateLiveActivityContent(info: primaryInfo)
            }
        } else if previousCount > 0 {
            endLiveActivity()
        }
    }

    @available(iOS 16.2, *)
    private func startLiveActivity(info: [String: Any]?) {
        let fileName = info?["fileName"] as? String ?? "Downloading..."
        let progress = info?["progress"] as? Double ?? 0
        let speed = info?["speed"] as? String ?? ""
        let eta = info?["eta"] as? String ?? "--"
        let downloadedSize = info?["downloadedSize"] as? String ?? "--"
        let totalSize = info?["totalSize"] as? String ?? "--"
        let status = info?["status"] as? String ?? "Queued"

        let attributes = DownloadActivityAttributes(downloadId: "active")
        let state = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            progress: progress,
            speed: speed,
            eta: eta,
            downloadedSize: downloadedSize,
            totalSize: totalSize,
            status: status,
            isCompleted: false
        )
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            liveActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            AppLogger.error("Failed to start Live Activity: \(error)", category: AppLogger.download)
        }
    }

    @available(iOS 16.2, *)
    private func updateLiveActivityContent(info: [String: Any]?) {
        guard let activity = liveActivity else { return }
        let fileName = info?["fileName"] as? String ?? "Downloading..."
        let progress = info?["progress"] as? Double ?? 0
        let speed = info?["speed"] as? String ?? ""
        let eta = info?["eta"] as? String ?? "--"
        let downloadedSize = info?["downloadedSize"] as? String ?? "--"
        let totalSize = info?["totalSize"] as? String ?? "--"
        let status = info?["status"] as? String ?? "Queued"

        let state = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            progress: progress,
            speed: speed,
            eta: eta,
            downloadedSize: downloadedSize,
            totalSize: totalSize,
            status: status,
            isCompleted: false
        )
        Task {
            await activity.update(using: state)
        }
    }

    @available(iOS 16.2, *)
    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        liveActivity = nil
        activeDownloadCount = 0
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
    }

    private func activeDownloadsPrimaryInfo() -> [String: Any]? {
        guard let first = downloads.first(where: { $0.status == .downloading }) else {
            return downloads.first.map { item in
                [
                    "fileName": item.fileName,
                    "progress": item.progress,
                    "speed": item.speedFormatted,
                    "eta": item.etaFormatted,
                    "downloadedSize": item.downloadedFormatted,
                    "totalSize": item.totalSizeFormatted,
                    "status": item.status.label,
                ]
            }
        }
        return [
            "fileName": first.fileName,
            "progress": first.progress,
            "speed": first.speedFormatted,
            "eta": first.etaFormatted,
            "downloadedSize": first.downloadedFormatted,
            "totalSize": first.totalSizeFormatted,
            "status": first.status.label,
        ]
    }

    // MARK: - Export/Import

    func exportQueue() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(downloads) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("dirxplore_queue_export.json")
        try? data.write(to: tempURL)
        return tempURL
    }

    func importQueue(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let imported = try? JSONDecoder().decode([DownloadItem].self, from: data) else { return }
        for item in imported {
            if !downloads.contains(where: { $0.id == item.id }) {
                downloads.append(item)
                let entity = DownloadEntity(id: item.id, url: item.url, fileName: item.fileName, savePath: item.savePath, status: .paused)
                DownloadRepository.shared.save(entity)
            }
        }
    }
}

// MARK: - URLSessionDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let downloadId = taskIdMap[downloadTask.taskIdentifier] else { return }
        progressMap[downloadId] = (totalBytesWritten, totalBytesExpectedToWrite)

        Task { @MainActor in
            guard let index = downloads.firstIndex(where: { $0.id == downloadId }) else { return }
            downloads[index].downloadedBytes = totalBytesWritten
            downloads[index].totalBytes = totalBytesExpectedToWrite
            if totalBytesExpectedToWrite > 0 {
                let speed = calculateSpeed(downloadId: downloadId, received: totalBytesWritten)
                downloads[index].speedBytesPerSec = downloads[index].speedBytesPerSec * AppConfiguration.speedSmoothingFactor + speed * (1 - AppConfiguration.speedSmoothingFactor)
                let remaining = Double(totalBytesExpectedToWrite - totalBytesWritten)
                let currentSpeed = downloads[index].speedBytesPerSec
                downloads[index].etaSeconds = currentSpeed > 0 ? remaining / currentSpeed : 0
            }
            totalDownloadedBytes += bytesWritten
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let downloadId = taskIdMap[downloadTask.taskIdentifier],
              let desc = downloadTask.taskDescription else { return }
        let parts = desc.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return }
        let fileName = String(parts[1])

        let destinationDir: URL
        if let customDir = saveDirMap[downloadId] {
            destinationDir = URL(fileURLWithPath: customDir)
        } else {
            destinationDir = defaultDownloadsPath()
        }

        try? FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        let destinationUrl = destinationDir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destinationUrl)

        do {
            try FileManager.default.moveItem(at: location, to: destinationUrl)
            Task { @MainActor in
                guard let index = downloads.firstIndex(where: { $0.id == downloadId }) else { return }
                downloads[index].status = .done
                downloads[index].savePath = destinationUrl.path
                persistDownloads()
                activeTasks.removeValue(forKey: downloadId)
                taskIdMap.removeValue(forKey: downloadTask.taskIdentifier)
                progressMap.removeValue(forKey: downloadId)
                retryCountMap.removeValue(forKey: downloadId)
                resumeDataMap.removeValue(forKey: downloadId)
                fileNameMap.removeValue(forKey: downloadId)
                activeCount = activeTasks.count
                updateLiveActivity()
                sendNotification(title: "Download Complete", body: fileName)
            }
        } catch {
            Task { @MainActor in
                guard let index = downloads.firstIndex(where: { $0.id == downloadId }) else { return }
                downloads[index].status = .error
                downloads[index].errorMessage = "Failed to move file: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadId = taskIdMap[task.taskIdentifier] else { return }
        if let error = error as NSError? {
            if error.code == NSURLErrorCancelled {
                if resumeDataMap[downloadId] == nil {
                    Task { @MainActor in
                        updateDownloadStatus(downloadId: downloadId, status: .paused)
                    }
                }
            } else if error.domain == NSURLErrorDomain && error.userInfo[NSURLSessionDownloadTaskResumeData] != nil {
                let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                if let data = resumeData {
                    resumeDataMap[downloadId] = data
                }
            } else {
                Task { @MainActor in
                    let attempt = retryCountMap[downloadId] ?? 0
                    if attempt < maxRetries, let downloadUrl = downloadUrlMap[downloadId] {
                        retryCountMap[downloadId] = attempt + 1
                        let delay = Double(1 << attempt)
                        AppLogger.info("Retrying download \(downloadId) in \(delay)s (attempt \(attempt + 1)/\(maxRetries))", category: AppLogger.download)
                        let delayNs = UInt64(delay * 1_000_000_000)
                        Task { @MainActor in
                            guard let self, self.retryCountMap[downloadId] != nil else { return }
                            try? await Task.sleep(nanoseconds: delayNs)
                            let resumeData = (error as NSError?)?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                            let newTask: URLSessionDownloadTask
                            if let data = resumeData {
                                newTask = self.backgroundSession.downloadTask(withResumeData: data)
                            } else {
                                var request = URLRequest(url: URL(string: downloadUrl)!)
                                request.setValue(AppConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
                                newTask = self.backgroundSession.downloadTask(with: request)
                            }
                            newTask.taskDescription = task.taskDescription ?? "\(downloadId)|\(fileNameMap[downloadId] ?? "file")"
                            self.activeTasks[downloadId] = newTask
                            self.taskIdMap[newTask.taskIdentifier] = downloadId
                            newTask.resume()
                        }
                    } else {
                        guard let index = downloads.firstIndex(where: { $0.id == downloadId }) else { return }
                        downloads[index].status = .error
                        downloads[index].errorMessage = error.localizedDescription
                        persistDownloads()
                        retryCountMap.removeValue(forKey: downloadId)
                        activeCount = activeTasks.count
                        updateLiveActivity()
                    }
                }
            }
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - Notifications

extension DownloadManager {
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Proxy Configuration

struct ProxyConfiguration {
    var host: String
    var port: Int
    var username: String
    var password: String
    var enabled: Bool
    var protocolType: String
}
