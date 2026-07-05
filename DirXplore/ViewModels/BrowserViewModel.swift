import Foundation
import SwiftUI

@MainActor
class BrowserViewModel: ObservableObject {
    @Published var currentURL: String = "http://172.16.50.4"
    @Published var directoryEntries: [DirectoryEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var bookmarks: [Bookmark] = []
    @Published var searchText = ""
    @Published var isSearching = false
    @Published var navigationHistory: [URL] = []
    @Published var canGoBack = false
    @Published var canGoForward = false

    private let networkService = NetworkService.shared
    private let defaults = UserDefaults.standard

    var filteredEntries: [DirectoryEntry] {
        if searchText.isEmpty { return directoryEntries }
        return directoryEntries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    init() {
        loadBookmarks()
    }

    func navigateToURL(_ urlString: String) {
        guard let url = URL(string: urlString.hasPrefix("http") ? urlString : "http://\(urlString)") else {
            errorMessage = "Invalid URL"
            return
        }
        errorMessage = nil
        let encodedURL = encodeURLIfNeeded(url)
        navigationHistory.append(encodedURL)
        canGoBack = navigationHistory.count > 1
        fetchDirectory(url: encodedURL)
    }

    private func encodeURLIfNeeded(_ url: URL) -> URL {
        if url.absoluteString.contains(" ") ||
           url.absoluteString.contains("'") ||
           url.absoluteString.contains("^") {
            guard let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let result = URL(string: encoded) else {
                return url
            }
            return result
        }
        return url
    }

    func fetchDirectory(url: URL) {
        isLoading = true
        errorMessage = nil
        currentURL = url.absoluteString

        Task {
            do {
                let entries = try await networkService.fetchDirectoryListing(url: url)
                directoryEntries = entries
            } catch {
                errorMessage = error.localizedDescription
                directoryEntries = []
            }
            isLoading = false
        }
    }

    func refresh() {
        guard let url = URL(string: currentURL) else { return }
        fetchDirectory(url: url)
    }

    func goBack() {
        guard navigationHistory.count >= 2 else { return }
        navigationHistory.removeLast()
        canGoForward = true
        if let url = navigationHistory.last {
            fetchDirectory(url: url)
        }
        canGoBack = navigationHistory.count > 1
    }

    func goForward() {
        // Simplified - would need separate forward stack
        refresh()
    }

    func openEntry(_ entry: DirectoryEntry) {
        if entry.isDirectory {
            fetchDirectory(url: entry.url)
        } else {
            // Download the file
            DownloadService.shared.startDownload(url: entry.url)
        }
    }

    // MARK: - Bookmarks

    func addBookmark(title: String, url: String) {
        let bookmark = Bookmark(title: title, url: url, dateAdded: Date())
        bookmarks.append(bookmark)
        saveBookmarks()
    }

    func removeBookmark(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        saveBookmarks()
    }

    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            defaults.set(data, forKey: "bookmarks")
        }
    }

    private func loadBookmarks() {
        guard let data = defaults.data(forKey: "bookmarks"),
              let items = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return
        }
        bookmarks = items
    }
}
