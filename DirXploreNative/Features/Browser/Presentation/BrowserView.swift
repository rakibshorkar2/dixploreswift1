import SwiftUI

@Observable
@MainActor
final class BrowserViewModel {
    var urlString = ""
    var entries: [DirectoryItem] = []
    var filteredEntries: [DirectoryItem] = []
    var searchQuery = ""
    var isLoading = false
    var errorMessage: String?
    var breadcrumbs: [(name: String, url: String)] = []
    var isGridView = false
    var showBookmarks = false
    var isFallbackMode = false
    var selectedCategory: String? = nil
    var sortFoldersFirst = true
    var selectedItems: Set<String> = []
    var isSelectionMode = false

    private var history: [String] = []
    private var historyIndex = -1
    private let parser = HtmlParser.shared

    let categories = ["All", "Movies", "Series/TV", "Games", "Software", "Anime", "Images"]

    func loadURL(_ url: String) {
        var normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
            normalizedURL = "https://\(normalizedURL)"
        }
        guard URL(string: normalizedURL) != nil else {
            errorMessage = "Invalid URL"
            return
        }

        urlString = normalizedURL
        isLoading = true
        errorMessage = nil

        if historyIndex == -1 || history.last != normalizedURL {
            if historyIndex < history.count - 1 {
                history = Array(history.prefix(historyIndex + 1))
            }
            history.append(normalizedURL)
            historyIndex = history.count - 1
        }

        Task {
            do {
                let html = try await HTTPClient.shared.getString(normalizedURL)
                let parsed = await parser.parseDirectoryListing(html: html, baseURL: normalizedURL)
                entries = parsed.map { entry in
                    DirectoryItem(
                        name: entry.name,
                        url: entry.href,
                        type: entry.isDirectory ? .directory : DirectoryItemType.from(fileExtension: (entry.name as NSString).pathExtension),
                        size: entry.size,
                        sizeLabel: entry.sizeLabel
                    )
                }
                updateBreadcrumbs(from: normalizedURL)
                applyFilters()
                isLoading = false
            } catch {
                isFallbackMode = true
                isLoading = false
                errorMessage = "Failed to load: \(error.localizedDescription)"
            }
        }
    }

    func loadBreadcrumb(at index: Int) {
        guard index < breadcrumbs.count else { return }
        let url = breadcrumbs[index].url
        loadURL(url)
    }

    func goBack() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        loadURL(history[historyIndex])
    }

    func goUp() {
        guard let currentURL = URL(string: urlString) else { return }
        let parent = currentURL.deletingLastPathComponent()
        loadURL(parent.absoluteString)
    }

    func search(_ query: String) {
        searchQuery = query
        applyFilters()
    }

    func filterByCategory(_ category: String?) {
        selectedCategory = category
        applyFilters()
    }

    func toggleViewMode() {
        isGridView.toggle()
    }

    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            for i in entries.indices { entries[i].isSelected = false }
            selectedItems.removeAll()
        }
    }

    func toggleSelection(for item: DirectoryItem) {
        guard let index = entries.firstIndex(where: { $0.id == item.id }) else { return }
        entries[index].isSelected.toggle()
        if entries[index].isSelected {
            selectedItems.insert(item.id.uuidString)
        } else {
            selectedItems.remove(item.id.uuidString)
        }
    }

    func selectAllFiltered() {
        for i in entries.indices where filteredEntries.contains(where: { $0.id == entries[i].id }) {
            entries[i].isSelected = true
            selectedItems.insert(entries[i].id.uuidString)
        }
    }

    func deselectAll() {
        for i in entries.indices { entries[i].isSelected = false }
        selectedItems.removeAll()
    }

    private func updateBreadcrumbs(from url: String) {
        breadcrumbs.removeAll()
        guard let components = URLComponents(string: url) else { return }
        let host = components.host ?? ""
        breadcrumbs.append((name: host, url: "\(components.scheme ?? "https")://\(host)"))
        let paths = components.path.split(separator: "/").filter { !$0.isEmpty }
        var currentURL = "\(components.scheme ?? "https")://\(host)"
        for path in paths {
            currentURL += "/\(path)"
            breadcrumbs.append((name: String(path), url: currentURL))
        }
    }

    private func applyFilters() {
        var result = entries

        if !searchQuery.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }

        if let category = selectedCategory, category != "All" {
            let types = categoryTypes(for: category)
            result = result.filter { types.contains($0.type) }
        }

        result.sort { a, b in
            if sortFoldersFirst {
                if a.type == .directory && b.type != .directory { return true }
                if a.type != .directory && b.type == .directory { return false }
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        filteredEntries = result
    }

    private func categoryTypes(for category: String) -> Set<DirectoryItemType> {
        switch category {
        case "Movies": return [.video]
        case "Series/TV": return [.video]
        case "Games": return [.archive]
        case "Software": return [.archive, .document]
        case "Anime": return [.video]
        case "Images": return [.image]
        default: return Set(DirectoryItemType.allCases)
        }
    }
}

struct BrowserView: View {
    @State private var vm = BrowserViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                urlBar
                breadcrumbBar
                categoryBar
                searchBar

                if vm.isLoading {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                } else if let error = vm.errorMessage {
                    Spacer()
                    ContentUnavailableView(
                        "Connection Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    Spacer()
                } else if vm.filteredEntries.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Files",
                        systemImage: "folder",
                        description: Text("This directory appears to be empty")
                    )
                    Spacer()
                } else {
                    if vm.isGridView {
                        gridView
                    } else {
                        listView
                    }
                }
            }
            .navigationTitle("Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if vm.isSelectionMode {
                            Button("Cancel") { vm.toggleSelectionMode() }
                        } else {
                            Button {
                                vm.showBookmarks = true
                            } label: {
                                Image(systemName: "bookmark")
                            }
                            Button {
                                vm.toggleViewMode()
                            } label: {
                                Image(systemName: vm.isGridView ? "list.bullet" : "square.grid.2x2")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $vm.showBookmarks) {
                BookmarksView(onSelect: { url in
                    vm.loadURL(url)
                    vm.showBookmarks = false
                })
            }
        }
    }

    private var urlBar: some View {
        HStack(spacing: 8) {
            Button { vm.goBack() } label: { Image(systemName: "chevron.left").font(.body) }
                .disabled(vm.historyIndex <= 0)
            Button { vm.goUp() } label: { Image(systemName: "chevron.up").font(.body) }
                .disabled(vm.urlString.isEmpty)

            TextField("Enter URL...", text: $vm.urlString)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)
                .onSubmit { vm.loadURL(vm.urlString) }

            Button { vm.loadURL(vm.urlString) } label: { Image(systemName: "arrow.right.circle.fill").font(.title2) }
                .disabled(vm.urlString.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(vm.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    Button {
                        vm.loadBreadcrumb(at: index)
                    } label: {
                        Text(crumb.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.secondary.opacity(0.2))
                    .controlSize(.small)

                    if index < vm.breadcrumbs.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(vm.categories, id: \.self) { category in
                    Button(category) {
                        vm.filterByCategory(category == vm.selectedCategory ? nil : category)
                    }
                    .buttonStyle(.bordered)
                    .tint(vm.selectedCategory == category ? .blue : .gray.opacity(0.3))
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search files...", text: $vm.searchQuery)
                .onChange(of: vm.searchQuery) { _, new in vm.search(new) }
            if !vm.searchQuery.isEmpty {
                Button { vm.search(""); vm.searchQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var listView: some View {
        List {
            ForEach(vm.filteredEntries) { item in
                DirectoryRow(item: item, isSelectionMode: vm.isSelectionMode) {
                    if vm.isSelectionMode {
                        vm.toggleSelection(for: item)
                    } else if item.type == .directory {
                        vm.loadURL(item.url)
                    }
                }
                .contextMenu {
                    if item.type == .directory {
                        Button { vm.loadURL(item.url) } label: { Label("Open", systemImage: "folder") }
                    }
                    Button { addToDownloads(item) } label: { Label("Download", systemImage: "arrow.down.circle") }
                    Button { copyLink(item) } label: { Label("Copy Link", systemImage: "doc.on.doc") }
                    Button { addToBookmarks(item) } label: { Label("Bookmark", systemImage: "bookmark") }
                }
                .swipeActions(edge: .trailing) {
                    Button { addToDownloads(item) } label: { Label("Download", systemImage: "arrow.down.circle") }
                        .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 150))], spacing: 12) {
                ForEach(vm.filteredEntries) { item in
                    DirectoryGridItem(item: item, isSelected: item.isSelected) {
                        if vm.isSelectionMode {
                            vm.toggleSelection(for: item)
                        } else if item.type == .directory {
                            vm.loadURL(item.url)
                        }
                    }
                    .contextMenu {
                        if item.type == .directory {
                            Button { vm.loadURL(item.url) } label: { Label("Open", systemImage: "folder") }
                        }
                        Button { addToDownloads(item) } label: { Label("Download", systemImage: "arrow.down.circle") }
                    }
                }
            }
            .padding()
        }
    }

    private func addToDownloads(_ item: DirectoryItem) {
        let fileName = item.name
        DownloadManager.shared.addDownload(url: item.url, fileName: fileName)
    }

    private func copyLink(_ item: DirectoryItem) {
        UIPasteboard.general.string = item.url
    }

    private func addToBookmarks(_ item: DirectoryItem) {
        BookmarkRepository.shared.save(name: item.name, url: item.url)
    }
}

struct DirectoryRow: View {
    let item: DirectoryItem
    let isSelectionMode: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isSelectionMode {
                    Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.isSelected ? .blue : .secondary)
                }
                Image(systemName: iconForType(item.type))
                    .foregroundColor(colorForType(item.type))
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(1)
                    if !item.sizeLabel.isEmpty {
                        Text(item.sizeLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if item.type == .directory {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct DirectoryGridItem: View {
    let item: DirectoryItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconForType(item.type))
                    .font(.largeTitle)
                    .foregroundColor(colorForType(item.type))
                Text(item.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if !item.sizeLabel.isEmpty {
                    Text(item.sizeLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.appSecondaryBackground)
            .cornerRadius(8)
            .overlay(isSelected ? RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 2) : nil)
        }
        .buttonStyle(.plain)
    }
}

private func iconForType(_ type: DirectoryItemType) -> String {
    switch type {
    case .directory: return "folder.fill"
    case .video: return "film.fill"
    case .audio: return "music.note"
    case .image: return "photo.fill"
    case .archive: return "archivebox.fill"
    case .document: return "doc.fill"
    case .other: return "questionmark"
    }
}

private func colorForType(_ type: DirectoryItemType) -> Color {
    switch type {
    case .directory: return .blue
    case .video: return .purple
    case .audio: return .pink
    case .image: return .green
    case .archive: return .orange
    case .document: return .gray
    case .other: return .secondary
    }
}

extension DirectoryItemType: CaseIterable {}
