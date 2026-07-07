import Foundation

enum AppConfiguration {
    static let appName = "DirXplore"
    static let appVersion = "2.0.0"
    static let buildNumber = 11

    static let backgroundDownloadIdentifier = "com.dirxplore.background.download"
    static let backgroundCrawlerIdentifier = "com.dirxplore.background.crawler"
    static let proxyTunnelPort: UInt16 = 9090

    static let maxConcurrentDownloadsDefault = 3
    static let maxRetriesDefault = 3
    static let speedSmoothingFactor = 0.7
    static let progressPersistenceInterval: TimeInterval = 5.0
    static let etaSmoothingFactor = 0.3

    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    static let liveActivityGroupIdentifier = "group.com.dirxplore"
    static let liveActivityWidgetIdentifier = "com.example.dirBrowser.WidgetExtension"
}
