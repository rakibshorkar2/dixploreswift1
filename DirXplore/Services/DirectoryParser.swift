import Foundation

class DirectoryParser {
    static let shared = DirectoryParser()

    func parseApacheDirectoryListing(html: String, baseURL: URL) -> [DirectoryEntry] {
        var entries: [DirectoryEntry] = []

        let pattern = "<a\\s+href=\"([^\"]+)\">([^<]+)</a>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return entries
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)

        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let hrefRange = Range(match.range(at: 1), in: html)!
            let textRange = Range(match.range(at: 2), in: html)!

            let href = String(html[hrefRange]).removingPercentEncoding ?? String(html[hrefRange])
            let text = String(html[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !href.hasPrefix("?") && !href.hasPrefix("#") else { continue }

            let isDirectory = href.hasSuffix("/")
            let name = isDirectory ? String(text.dropLast()) : text

            guard !name.isEmpty && name != "Parent Directory" else { continue }

            let entryURL: URL
            if let resolved = URL(string: href, relativeTo: baseURL) {
                entryURL = resolved
            } else if let encoded = href.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                      let resolved = URL(string: encoded, relativeTo: baseURL) {
                entryURL = resolved
            } else {
                entryURL = baseURL.appendingPathComponent(href)
            }

            entries.append(DirectoryEntry(
                name: name,
                path: href,
                isDirectory: isDirectory,
                size: 0,
                modificationDate: nil,
                url: entryURL
            ))
        }

        return entries
    }

    func parseFTPStyleListing(text: String, baseURL: URL) -> [DirectoryEntry] {
        var entries: [DirectoryEntry] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 8 else { continue }

            let permissions = String(parts[0])
            let isDirectory = permissions.hasPrefix("d")
            let size = Int64(String(parts[4])) ?? 0

            let name = parts.dropFirst(8).joined(separator: " ")
            guard !name.isEmpty && name != "." && name != ".." else { continue }

            let entryURL = baseURL.appendingPathComponent(name)

            entries.append(DirectoryEntry(
                name: name,
                path: "/" + name,
                isDirectory: isDirectory,
                size: size,
                modificationDate: nil,
                url: entryURL
            ))
        }

        return entries
    }
}
