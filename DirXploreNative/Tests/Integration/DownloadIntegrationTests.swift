import XCTest
@testable import DirXplore

final class DownloadIntegrationTests: XCTestCase {
    @MainActor func testFullDownloadLifecycle() async throws {
        let dm = DownloadManager.shared
        let testURL = "https://httpbin.org/bytes/1024"
        let id = dm.addDownload(url: testURL, fileName: "test_1024_bytes.bin")

        XCTAssertFalse(id.isEmpty)
        XCTAssertTrue(dm.downloads.contains(where: { $0.id == id }))

        try await Task.sleep(nanoseconds: 2_000_000_000)

        dm.pauseDownload(downloadId: id)
        try await Task.sleep(nanoseconds: 500_000_000)

        let pausedItem = dm.downloads.first(where: { $0.id == id })
        XCTAssertNotNil(pausedItem)
        XCTAssertEqual(pausedItem?.status, .paused)

        dm.resumeDownload(downloadId: id)
        try await Task.sleep(nanoseconds: 500_000_000)

        dm.cancelDownload(downloadId: id)
        try await Task.sleep(nanoseconds: 500_000_000)

        let cancelledItem = dm.downloads.first(where: { $0.id == id })
        XCTAssertNotNil(cancelledItem)
    }
}
