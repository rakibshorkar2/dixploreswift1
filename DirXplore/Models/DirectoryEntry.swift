import Foundation

struct DirectoryEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let url: URL

    var formattedSize: String {
        if isDirectory { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
