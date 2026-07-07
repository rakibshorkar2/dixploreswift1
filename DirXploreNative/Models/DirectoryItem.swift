import Foundation
import UniformTypeIdentifiers

enum DirectoryItemType: String, Codable, Sendable, CaseIterable {
    case directory, video, audio, image, archive, document, other

    var tag: String {
        switch self {
        case .directory: return "[DIR]"
        case .video: return "[VID]"
        case .audio: return "[AUD]"
        case .image: return "[IMG]"
        case .archive: return "[ARC]"
        case .document: return "[DOC]"
        case .other: return "[OTH]"
        }
    }
}

struct DirectoryItem: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var url: String
    var type: DirectoryItemType
    var size: Int64
    var sizeLabel: String
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        type: DirectoryItemType = .other,
        size: Int64 = 0,
        sizeLabel: String = "",
        isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.type = type
        self.size = size
        self.sizeLabel = sizeLabel
        self.isSelected = isSelected
    }
}

extension DirectoryItemType {
    static func from(fileExtension: String) -> DirectoryItemType {
        switch fileExtension.lowercased() {
        case _ where [""].contains(fileExtension.lowercased()):
            return .directory
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "3gp", "ts", "m3u8":
            return .video
        case "mp3", "wav", "flac", "aac", "ogg", "wma", "m4a", "opus":
            return .audio
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic", "ico":
            return .image
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso":
            return .archive
        case "pdf", "txt", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "md", "rtf":
            return .document
        default:
            return .other
        }
    }

    static func from(mimeType: String) -> DirectoryItemType {
        if mimeType.hasPrefix("video/") { return .video }
        if mimeType.hasPrefix("audio/") { return .audio }
        if mimeType.hasPrefix("image/") { return .image }
        if mimeType == "application/pdf" || mimeType.hasPrefix("text/") { return .document }
        if mimeType.contains("zip") || mimeType.contains("rar") || mimeType.contains("tar") { return .archive }
        return .other
    }
}
