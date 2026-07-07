import Foundation

struct UpdateInfo: Sendable {
    var version: String
    var downloadURL: String
    var releaseNotes: String
}

actor GitHubUpdater {
    static let shared = GitHubUpdater()
    private let repo = "rakibshorkar2/dirxplore1"

    func checkForUpdates() async -> UpdateInfo? {
        let url = "https://api.github.com/repos/\(repo)/releases/latest"
        do {
            let data = try await HTTPClient.shared.get(url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let tag = json?["tag_name"] as? String,
                  let releaseNotes = json?["body"] as? String else { return nil }

            var downloadURL = ""
            if let assets = json?["assets"] as? [[String: Any]] {
                downloadURL = assets.first { ($0["name"] as? String)?.hasSuffix(".ipa") ?? false }?["browser_download_url"] as? String ?? ""
            }

            return UpdateInfo(version: tag, downloadURL: downloadURL, releaseNotes: releaseNotes)
        } catch {
            AppLogger.error("Failed to check updates: \(error)")
            return nil
        }
    }

    func compareVersions(_ v1: String, _ v2: String) -> Bool {
        let parts1 = v1.components(separatedBy: ".").compactMap(Int.init)
        let parts2 = v2.components(separatedBy: ".").compactMap(Int.init)
        for i in 0..<max(parts1.count, parts2.count) {
            let a = i < parts1.count ? parts1[i] : 0
            let b = i < parts2.count ? parts2[i] : 0
            if a != b { return a > b }
        }
        return false
    }
}
