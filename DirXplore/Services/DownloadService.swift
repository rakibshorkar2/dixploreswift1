import Foundation
import BackgroundTasks
import ActivityKit

@MainActor
class DownloadService: NSObject, ObservableObject {
    static let shared = DownloadService()

    @Published var activeDownloads: [UUID: DownloadTaskItem] = [:]
    @Published var completedDownloads: [DownloadTaskItem] = []

    private var urlSession: URLSession!
    var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    var progressObservers: [UUID: NSKeyValueObservation] = [:]

    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.example.dirBrowser.background")
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

        let taskID = task.id
        progressObservers[task.id] = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
            Task { @MainActor in
                DownloadService.shared.activeDownloads[taskID]?.progress = progress.fractionCompleted
                DownloadService.shared.updateLiveActivity(for: taskID, progress: progress.fractionCompleted)
            }
        }

        downloadTask.resume()
        startLiveActivity(for: task)
    }

    func pauseDownload(id: UUID) {
        guard activeDownloads[id] != nil else { return }
        activeDownloads[id]?.status = .paused
        let pausedID = id
        downloadTasks[id]?.cancel(byProducingResumeData: { resumeData in
            Task { @MainActor in
                DownloadService.shared.activeDownloads[pausedID]?.resumeData = resumeData
            }
        })
    }

    func resumeDownload(id: UUID) {
        guard activeDownloads[id] != nil else { return }
        activeDownloads[id]?.status = .downloading

        if let resumeData = activeDownloads[id]?.resumeData {
            let downloadTask = urlSession.downloadTask(withResumeData: resumeData)
            downloadTasks[id] = downloadTask
            downloadTask.resume()
        } else if let url = activeDownloads[id]?.url {
            startDownload(url: url)
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
        let state = DownloadProgressAttributes.ContentState(progress: 0, status: "downloading")

        let content = ActivityContent(state: state, staleDate: nil)
        let activity = try? Activity.request(attributes: attributes, content: content)
        liveActivities[task.id] = activity
    }

    private func updateLiveActivity(for id: UUID, progress: Double) {
        guard let activity = liveActivities[id] else { return }
        let state = DownloadProgressAttributes.ContentState(progress: progress, status: "downloading")
        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
    }

    private func endLiveActivity(for id: UUID) {
        guard let activity = liveActivities[id] else { return }
        let state = DownloadProgressAttributes.ContentState(progress: 1.0, status: "completed")
        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.end(content, dismissalPolicy: .default)
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
        guard let id = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              let filename = downloadTask.originalRequest?.url?.lastPathComponent
        else { return }

        StorageService.shared.saveDownloadedFile(from: location, filename: filename)

        Task { @MainActor [id] in
            DownloadService.shared.activeDownloads[id]?.status = .completed
            DownloadService.shared.activeDownloads[id]?.progress = 1.0

            if let item = DownloadService.shared.activeDownloads[id] {
                DownloadService.shared.completedDownloads.append(item)
            }

            DownloadService.shared.endLiveActivity(for: id)
        }

        if let observer = progressObservers[id] {
            observer.invalidate()
            progressObservers.removeValue(forKey: id)
        }
        downloadTasks.removeValue(forKey: id)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = downloadTasks.first(where: { $0.value == task })?.key else { return }
        if let error = error as? URLError, error.code != .cancelled {
            Task { @MainActor [id] in
                DownloadService.shared.activeDownloads[id]?.status = .failed
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTasks.first(where: { $0.value == downloadTask })?.key else { return }
        Task { @MainActor [id, totalBytesWritten, totalBytesExpectedToWrite] in
            DownloadService.shared.activeDownloads[id]?.downloadedBytes = totalBytesWritten
            DownloadService.shared.activeDownloads[id]?.totalBytes = totalBytesExpectedToWrite
            if totalBytesExpectedToWrite > 0 {
                DownloadService.shared.activeDownloads[id]?.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }
}
