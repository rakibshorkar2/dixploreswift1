import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.dirxplore"

    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let download = Logger(subsystem: subsystem, category: "download")
    static let crawler = Logger(subsystem: subsystem, category: "crawler")
    static let parser = Logger(subsystem: subsystem, category: "parser")
    static let torrent = Logger(subsystem: subsystem, category: "torrent")
    static let proxy = Logger(subsystem: subsystem, category: "proxy")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let general = Logger(subsystem: subsystem, category: "general")

    static func debug(_ message: String, category: Logger = general) {
        category.debug("\(message, privacy: .public)")
    }

    static func info(_ message: String, category: Logger = general) {
        category.info("\(message, privacy: .public)")
    }

    static func error(_ message: String, category: Logger = general) {
        category.error("\(message, privacy: .public)")
    }

    static func fault(_ message: String, category: Logger = general) {
        category.fault("\(message, privacy: .public)")
    }
}
