import Foundation
import SwiftUI

@MainActor
class DownloadsViewModel: ObservableObject {
    @Published var downloadItems: [DownloadTaskItem] = []
    @Published var activeDownloadCount: Int = 0
    @Published var completedDownloadCount: Int = 0

    private let downloadService = DownloadService.shared
    private var cancellables: [NSObjectProtocol] = []

    var activeDownloads: [DownloadTaskItem] {
        downloadItems.filter { $0.status == .downloading || $0.status == .pending }
    }

    var pausedDownloads: [DownloadTaskItem] {
        downloadItems.filter { $0.status == .paused }
    }

    var finishedDownloads: [DownloadTaskItem] {
        downloadItems.filter { $0.status == .completed || $0.status == .failed }
    }

    init() {
        refreshState()
        setupObservers()
    }

    private func setupObservers() {
        Task { @MainActor in
            for await _ in downloadService.$activeDownloads.values {
                self.refreshState()
            }
        }
        Task { @MainActor in
            for await _ in downloadService.$completedDownloads.values {
                self.refreshState()
            }
        }
    }

    func startDownload(url: URL) {
        downloadService.startDownload(url: url)
    }

    func pauseDownload(id: UUID) {
        downloadService.pauseDownload(id: id)
    }

    func resumeDownload(id: UUID) {
        downloadService.resumeDownload(id: id)
    }

    func cancelDownload(id: UUID) {
        downloadService.cancelDownload(id: id)
    }

    func pauseAll() {
        downloadService.pauseAll()
    }

    func resumeAll() {
        downloadService.resumeAll()
    }

    func cancelAll() {
        downloadService.cancelAll()
    }

    func deleteDownload(id: UUID) {
        downloadService.deleteDownload(id: id)
    }

    func deleteAllCompleted() {
        downloadService.deleteAllCompleted()
    }

    func refreshState() {
        downloadItems = Array(downloadService.activeDownloads.values) + downloadService.completedDownloads
        activeDownloadCount = activeDownloads.count
        completedDownloadCount = finishedDownloads.count
    }
}
