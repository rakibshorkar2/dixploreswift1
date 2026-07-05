import Foundation
import BackgroundTasks
import ActivityKit

@MainActor
class DownloadService: NSObject, ObservableObject {
    static let shared = DownloadService()

    @Published var activeDownloads: [UUID: DownloadTaskItem] = [:]
    @Published var completedDownloads: [DownloadTaskItem] = []

    private var urlSession: URLSession!
    private var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    private var progressObservers: [UUID: NSKeyValueObservation] = [:]

    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.rakib.dirxplore.background")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func startDownload(url: URL) {
        let task = DownloadTaskItem(
            url: url,
            filename: url.lastPathComponent,
            status: .downloading,
            progress: 0,
            totalBytes: 0,
            downloadedBytes: 0,
            startDate: Date()
        )

        activeDownloads[task.id] = task

        let downloadTask = urlSession.downloadTask(with: url)
        downloadTasks[task.id] = downloadTask

        progressObservers[task.id] = downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.activeDownloads[task.id]?.progress = progress.fractionCompleted
                self?.updateLiveActivity(for: task.id, progress: progress.fractionCompleted)
            }
        }

        downloadTask.resume()
        startLiveActivity(for: task)
    }

    func pauseDownload(id: UUID) {
        guard let task = activeDownloads[id] else { return }
        task.status = .paused
        downloadTasks[id]?.cancel(byProducingResumeData: { resumeData in
            Task { @MainActor in
                self.activeDownloads[id]?.resumeData = resumeData
            }
        })
    }

    func resumeDownload(id: UUID) {
        guard var task = activeDownloads[id] else { return }
        task.status = .downloading

        if let resumeData = task.resumeData {
            let downloadTask = urlSession.downloadTask(withResumeData: resumeData)
            downloadTasks[id] = downloadTask
            downloadTask.resume()
        } else {
            startDownload(url: task.url)
        }
    }

    func cancelDownload(id: UUID) {
        downloadTasks[id]?.cancel()
        progressObservers[id]?.invalidate()
        progressObservers.removeValue(forKey: id)
        downloadTasks.removeValue(forKey: id)
        activeDownloads.removeValue(forKey: id)
        endLiveActivity(for: id)
    }

    func pauseAll() {
        for id in activeDownloads.keys {
            pauseDownload(id: id)
        }
    }

    func resumeAll() {
        for id in activeDownloads.keys {
            resumeDownload(id: id)
        }
    }

    func cancelAll() {
        for id in activeDownloads.keys {
            cancelDownload(id: id)
        }
    }

    func deleteDownload(id: UUID) {
        activeDownloads.removeValue(forKey: id)
        completedDownloads.removeAll { $0.id == id }
    }

    func deleteAllCompleted() {
        completedDownloads.removeAll()
    }

    // MARK: - Live Activity

    private var liveActivities: [UUID: Activity<DownloadProgressAttributes>] = [:]

    private func startLiveActivity(for task: DownloadTaskItem) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = DownloadProgressAttributes(filename: task.filename)
        let state = DownloadProgressAttributes.ContentState(progress: 0, status: .downloading)

        let content = ActivityContent(state: state, staleDate: nil)
        let activity = try? Activity.request(attributes: attributes, content: content)
        liveActivities[task.id] = activity
    }

    private func updateLiveActivity(for id: UUID, progress: Double) {
        guard let activity = liveActivities[id] else { return }
        let state = DownloadProgressAttributes.ContentState(progress: progress, status: .downloading)
        Task {
            await activity.update(using: state)
        }
    }

    private func endLiveActivity(for id: UUID) {
        guard let activity = liveActivities[id] else { return }
        let state = DownloadProgressAttributes.ContentState(progress: 1.0, status: .completed)
        Task {
            await activity.end(using: state, dismissalPolicy: .default)
        }
        liveActivities.removeValue(forKey: id)
    }

    func handleBackgroundDownload(task: BGProcessingTask) {
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        task.setTaskCompleted(success: true)
    }
}

// MARK: - Live Activity Attributes

struct DownloadProgressAttributes: ActivityAttributes {
    public typealias DownloadStatus = String

    public struct ContentState: Codable, Hashable {
        var progress: Double
        var status: DownloadStatus
    }

    var filename: String
}

// MARK: - URLSessionDownloadDelegate

extension DownloadService: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let id = downloadTasks.first(where: { $0.value == downloadTask })?.key else { return }

        Task { @MainActor in
            let destURL = StorageService.shared.saveDownloadedFile(from: location, filename: downloadTask.originalRequest?.url?.lastPathComponent ?? "file")
            self.activeDownloads[id]?.status = .completed
            self.activeDownloads[id]?.progress = 1.0

            if let item = self.activeDownloads[id] {
                self.completedDownloads.append(item)
            }

            self.endLiveActivity(for: id)
            self.progressObservers[id]?.invalidate()
            self.progressObservers.removeValue(forKey: id)
            self.downloadTasks.removeValue(forKey: id)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = downloadTasks.first(where: { $0.value == task })?.key else { return }
        if let error = error as? URLError, error.code != .cancelled {
            Task { @MainActor in
                self.activeDownloads[id]?.status = .failed
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTasks.first(where: { $0.value == downloadTask })?.key else { return }
        Task { @MainActor in
            self.activeDownloads[id]?.downloadedBytes = totalBytesWritten
            self.activeDownloads[id]?.totalBytes = totalBytesExpectedToWrite
            if totalBytesExpectedToWrite > 0 {
                self.activeDownloads[id]?.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }
}
