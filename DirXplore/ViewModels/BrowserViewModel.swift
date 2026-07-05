import Foundation
import SwiftUI

enum SortField: String, CaseIterable {
    case name = "Name"
    case size = "Size"
    case date = "Date"
}

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
    @Published var sortField: SortField = .name
    @Published var sortAscending = true

    private var forwardStack: [URL] = []
    private var loadingTask: Task<Void, Never>?

    private let networkService = NetworkService.shared
    private let defaults = UserDefaults.standard

    var filteredEntries: [DirectoryEntry] {
        let filtered = searchText.isEmpty
            ? directoryEntries
            : directoryEntries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return filtered.sorted { a, b in
            let result: Bool
            switch sortField {
            case .name: result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .size: result = a.size < b.size
            case .date:
                switch (a.modificationDate, b.modificationDate) {
                case let (l?, r?): result = l < r
                case (nil, _): result = false
                case (_?, nil): result = true
                case (nil, nil): result = a.name < b.name
                }
            }
            return sortAscending ? result : !result
        }
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
        forwardStack.removeAll()
        canGoForward = false
        fetchDirectory(url: encodedURL)
    }

    func openEntry(_ entry: DirectoryEntry) {
        if entry.isDirectory {
            let url = entry.url.absoluteURL
            navigationHistory.append(url)
            canGoBack = navigationHistory.count > 1
            forwardStack.removeAll()
            canGoForward = false
            fetchDirectory(url: url)
        } else {
            DownloadService.shared.startDownload(url: entry.url.absoluteURL)
        }
    }

    func stopLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        isLoading = false
        errorMessage = "Loading cancelled"
    }

    func copyToClipboard(url: URL) {
        UIPasteboard.general.url = url
    }

    func openInSafari(url: URL) {
        UIApplication.shared.open(url)
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
        loadingTask?.cancel()
        isLoading = true
        errorMessage = nil
        currentURL = url.absoluteString

        loadingTask = Task {
            do {
                let entries = try await networkService.fetchDirectoryListing(url: url)
                directoryEntries = entries
            } catch {
                if Task.isCancelled { return }
                if (error as? URLError)?.code == .cancelled { return }
                errorMessage = error.localizedDescription
                directoryEntries = []
            }
            isLoading = false
            loadingTask = nil
        }
    }

    func refresh() {
        guard let url = URL(string: currentURL) else { return }
        fetchDirectory(url: url)
    }

    func goBack() {
        guard navigationHistory.count >= 2 else { return }
        let current = navigationHistory.removeLast()
        forwardStack.append(current)
        canGoForward = true
        if let url = navigationHistory.last {
            fetchDirectory(url: url)
        }
        canGoBack = navigationHistory.count > 1
    }

    func goForward() {
        guard !forwardStack.isEmpty else { return }
        let url = forwardStack.removeLast()
        navigationHistory.append(url)
        canGoBack = navigationHistory.count > 1
        canGoForward = !forwardStack.isEmpty
        fetchDirectory(url: url)
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

    // MARK: - History

    var recentURLs: [String] {
        navigationHistory.map { $0.absoluteString }.reversed()
    }

    func clearHistory() {
        navigationHistory.removeAll()
        forwardStack.removeAll()
        canGoBack = false
        canGoForward = false
    }
}
