import XCTest
@testable import DirXplore

final class DownloadManagerTests: XCTestCase {
    var dm: DownloadManager!

    @MainActor override func setUp() {
        super.setUp()
        dm = DownloadManager.shared
    }

    @MainActor func testAddDownload() {
        let id = dm.addDownload(url: "https://example.com/file.zip", fileName: "file.zip")
        XCTAssertFalse(id.isEmpty)
        XCTAssertTrue(dm.downloads.contains(where: { $0.id == id }))
    }

    @MainActor func testDownloadInitialStatus() {
        let id = dm.addDownload(url: "https://example.com/file.zip", fileName: "test.zip")
        guard let item = dm.downloads.first(where: { $0.id == id }) else {
            XCTFail("Download not found"); return
        }
        XCTAssertEqual(item.status, .queued)
        XCTAssertEqual(item.fileName, "test.zip")
    }

    @MainActor func testCancelDownload() {
        let id = dm.addDownload(url: "https://example.com/file.zip", fileName: "test.zip")
        dm.cancelDownload(downloadId: id)
        guard let item = dm.downloads.first(where: { $0.id == id }) else {
            XCTFail("Download not found"); return
        }
        XCTAssertEqual(item.status, .error)
    }

    @MainActor func testClearCompleted() {
        dm.addDownload(url: "https://example.com/a.zip", fileName: "a.zip")
        dm.addDownload(url: "https://example.com/b.zip", fileName: "b.zip")
        let initialCount = dm.downloads.count
        dm.clearCompleted()
        XCTAssertEqual(dm.downloads.count, initialCount)
    }

    func testByteFormatting() {
        let item = DownloadItem(id: "1", url: "", fileName: "", savePath: "", status: .done, totalBytes: 1_073_741_824, downloadedBytes: 1_073_741_824)
        XCTAssertEqual(item.totalSizeFormatted, "1 GB")
    }

    func testProgressCalculation() {
        let item = DownloadItem(id: "1", url: "", fileName: "", savePath: "", status: .downloading, totalBytes: 1000, downloadedBytes: 250)
        XCTAssertEqual(item.progress, 0.25, accuracy: 0.01)
    }

    func testEmptyProgress() {
        let item = DownloadItem(id: "1", url: "", fileName: "", savePath: "", status: .queued, totalBytes: 0, downloadedBytes: 0)
        XCTAssertEqual(item.progress, 0)
    }
}
