import Foundation

actor HtmlParser {
    static let shared = HtmlParser()

    private init() {}

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    struct ParsedEntry: Sendable {
        var name: String
        var href: String
        var size: Int64
        var sizeLabel: String
        var isDirectory: Bool
        var modifiedAt: Date?
    }

    func parseDirectoryListing(html: String, baseURL: String) -> [ParsedEntry] {
        var entries: [ParsedEntry] = []

        let lines = html.components(separatedBy: .newlines)

        var inTable = false
        var inRow = false
        var cells: [String] = []
        var currentCell = ""
        var inAnchor = false
        var anchorHref = ""
        var anchorText = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.contains("<table") {
                inTable = true
                continue
            }
            if trimmed.contains("</table>") {
                inTable = false
                continue
            }

            guard inTable else {
                if !inTable, !trimmed.isEmpty {
                    let linkPattern = try? NSRegularExpression(pattern: "<a\\s+href=\"([^\"]+)\"[^>]*>([^<]*)</a>")
                    if let match = linkPattern?.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                        let hrefRange = Range(match.range(at: 1), in: trimmed)!
                        let textRange = Range(match.range(at: 2), in: trimmed)!
                        let href = String(trimmed[hrefRange])
                        let text = String(trimmed[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty, text != "Parent Directory", text != "../" {
                            let isDir = href.hasSuffix("/")
                            entries.append(ParsedEntry(
                                name: text,
                                href: resolveURL(href: href, base: baseURL),
                                size: 0,
                                sizeLabel: isDir ? "-" : "",
                                isDirectory: isDir,
                                modifiedAt: nil
                            ))
                        }
                    }
                }
                continue
            }

            if trimmed.contains("<tr") { inRow = true; cells = []; continue }
            if trimmed.contains("</tr>") && inRow {
                inRow = false
                if cells.count >= 2 {
                    let name = cells[0]
                    if name != "Parent Directory" && !name.isEmpty {
                        let href = extractHref(from: name)
                        let cleanName = stripHTML(name)
                        let isDir = href.hasSuffix("/") || cells.count < 3
                        let sizeStr = cells.count >= 3 ? stripHTML(cells[2]) : "-"
                        let size = parseSize(sizeStr)
                        entries.append(ParsedEntry(
                            name: cleanName,
                            href: resolveURL(href: href, base: baseURL),
                            size: size,
                            sizeLabel: sizeStr,
                            isDirectory: isDir,
                            modifiedAt: nil
                        ))
                    }
                }
                continue
            }

            if inRow {
                if trimmed.contains("<td") {
                    currentCell = ""
                }
                if trimmed.contains("</td>") {
                    cells.append(currentCell)
                    currentCell = ""
                }
                if trimmed.hasPrefix("<") {
                    currentCell += trimmed
                } else {
                    currentCell += trimmed
                }
            }
        }

        return entries.filter { $0.name != ".." && $0.name != "../" && !$0.href.hasSuffix("/?") }
    }

    private func extractHref(from html: String) -> String {
        let pattern = try? NSRegularExpression(pattern: "href=\"([^\"]+)\"")
        guard let match = pattern?.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) else {
            return ""
        }
        let range = Range(match.range(at: 1), in: html)!
        return String(html[range])
    }

    private func stripHTML(_ html: String) -> String {
        let pattern = try? NSRegularExpression(pattern: "<[^>]+>")
        let range = NSRange(html.startIndex..., in: html)
        return pattern?.stringByReplacingMatches(in: html, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? html
    }

    private func parseSize(_ str: String) -> Int64 {
        let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned == "-" || cleaned.isEmpty { return 0 }
        let numberStr = cleaned.components(separatedBy: CharacterSet.letters.union(CharacterSet(charactersIn: "."))).joined()
        guard let number = Double(numberStr) else { return 0 }
        if cleaned.contains("TB") { return Int64(number * 1_099_511_627_776) }
        if cleaned.contains("GB") { return Int64(number * 1_073_741_824) }
        if cleaned.contains("MB") { return Int64(number * 1_048_576) }
        if cleaned.contains("KB") { return Int64(number * 1_024) }
        if cleaned.contains("B") { return Int64(number) }
        return Int64(number)
    }

    private func resolveURL(href: String, base: String) -> String {
        guard !href.hasPrefix("http://"), !href.hasPrefix("https://") else { return href }
        var baseURL = base
        if !baseURL.hasSuffix("/") { baseURL += "/" }
        let cleanHref = href.hasPrefix("/") ? String(href.dropFirst()) : href
        return baseURL + cleanHref
    }
}
