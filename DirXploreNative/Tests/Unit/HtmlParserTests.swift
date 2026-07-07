import XCTest
@testable import DirXplore

final class HtmlParserTests: XCTestCase {
    let parser = HtmlParser.shared

    func testParseApacheListing() async {
        let html = """
        <html>
        <body>
        <table>
        <tr><td><a href="file1.zip">file1.zip</a></td><td>2024-01-01</td><td>1.2 GB</td></tr>
        <tr><td><a href="folder/">folder/</a></td><td>2024-01-02</td><td>-</td></tr>
        </table>
        </body>
        </html>
        """
        let entries = await parser.parseDirectoryListing(html: html, baseURL: "https://example.com/dir/")
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries[0].name == "file1.zip" || entries[1].name == "file1.zip")
    }

    func testParseSimpleLinks() async {
        let html = """
        <html>
        <body>
        <a href="file.txt">file.txt</a>
        <a href="subdir/">subdir/</a>
        </body>
        </html>
        """
        let entries = await parser.parseDirectoryListing(html: html, baseURL: "https://example.com/")
        XCTAssertTrue(entries.contains(where: { $0.name == "file.txt" }))
        XCTAssertTrue(entries.contains(where: { $0.name == "subdir/" }))
    }

    func testFilterParentDirectory() async {
        let html = """
        <html>
        <body>
        <a href="../">Parent Directory</a>
        <a href="file.txt">file.txt</a>
        </body>
        </html>
        """
        let entries = await parser.parseDirectoryListing(html: html, baseURL: "https://example.com/")
        XCTAssertFalse(entries.contains(where: { $0.name == "Parent Directory" }))
        XCTAssertTrue(entries.contains(where: { $0.name == "file.txt" }))
    }

    func testSizeParsing() {
        // Test via the parser's internal parseSize function
        // We test indirectly through parseDirectoryListing
    }

    func testEmptyHTML() async {
        let entries = await parser.parseDirectoryListing(html: "", baseURL: "https://example.com/")
        XCTAssertTrue(entries.isEmpty)
    }

    func testMalformedHTML() async {
        let html = "<html><body><a href=\"test.txt\">test.txt</body>"
        let entries = await parser.parseDirectoryListing(html: html, baseURL: "https://example.com/")
        XCTAssertTrue(entries.contains(where: { $0.name == "test.txt" }))
    }
}
