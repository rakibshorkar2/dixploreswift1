import XCTest
@testable import DirXplore

final class DirectoryItemTests: XCTestCase {
    func testTypeFromExtension() {
        XCTAssertEqual(DirectoryItemType.from(fileExtension: "mp4"), .video)
        XCTAssertEqual(DirectoryItemType.from(fileExtension: "MKV"), .video)
        XCTAssertEqual(DirectoryItemType.from(fileExtension: "mp3"), .audio)
        XCTAssertEqual(DirectoryItemType.from(fileExtension: "jpg"), .image)
        XCTAssertEqual(DirectoryItemType.from(fileExtension: "zip"), .archive)
        XCTAssertEqual(DirectoryItemType.from(fileExtension: "pdf"), .document)
        XCTAssertEqual(DirectoryItemType.from(fileExtension: "txt"), .document)
        XCTAssertEqual(DirectoryItemType.from(fileExtension: "xyz"), .other)
    }

    func testTypeTag() {
        XCTAssertEqual(DirectoryItemType.directory.tag, "[DIR]")
        XCTAssertEqual(DirectoryItemType.video.tag, "[VID]")
        XCTAssertEqual(DirectoryItemType.audio.tag, "[AUD]")
        XCTAssertEqual(DirectoryItemType.image.tag, "[IMG]")
    }

    func testItemHashable() {
        let a = DirectoryItem(name: "test.mp4", url: "http://example.com/test.mp4", type: .video)
        let b = DirectoryItem(name: "test.mp4", url: "http://example.com/test.mp4", type: .video)
        XCTAssertEqual(a, b)
    }

    func testItemSizeLabel() {
        let item = DirectoryItem(name: "file.zip", url: "", size: 1_073_741_824, sizeLabel: "1.0 GB")
        XCTAssertEqual(item.sizeLabel, "1.0 GB")
    }

    func testMimeTypeMapping() {
        XCTAssertEqual(DirectoryItemType.from(mimeType: "video/mp4"), .video)
        XCTAssertEqual(DirectoryItemType.from(mimeType: "audio/mpeg"), .audio)
        XCTAssertEqual(DirectoryItemType.from(mimeType: "image/png"), .image)
        XCTAssertEqual(DirectoryItemType.from(mimeType: "application/zip"), .archive)
        XCTAssertEqual(DirectoryItemType.from(mimeType: "application/pdf"), .document)
    }
}
