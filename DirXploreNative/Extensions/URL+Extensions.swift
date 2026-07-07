import Foundation

extension URL {
    var fileName: String {
        lastPathComponent
    }

    var fileExtension: String {
        pathExtension
    }

    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    var fileSize: Int64 {
        (try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
    }

    func relativePath(from base: URL) -> String {
        let basePath = base.path.hasSuffix("/") ? base.path : base.path + "/"
        guard path.hasPrefix(basePath) else { return path }
        return String(path.dropFirst(basePath.count))
    }

    func securityScopedAccess<T>(_ block: (URL) throws -> T) rethrows -> T {
        let accessing = startAccessingSecurityScopedResource()
        defer { if accessing { stopAccessingSecurityScopedResource() } }
        return try block(self)
    }
}
