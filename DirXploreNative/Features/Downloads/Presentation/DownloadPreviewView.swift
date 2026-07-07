import SwiftUI

@Observable
@MainActor
final class DownloadPreviewViewModel {
    var entries: [DirectoryItem] = []
    var filteredEntries: [DirectoryItem] = []
    var filterText = ""
    var filterChip: FilterChip = .all
    var isLoading = false

    enum FilterChip: String, CaseIterable {
        case all = "All"
        case videos = "Videos"
        case archives = "Archives"
        case hd = "1080p"
        case hd720 = "720p"
        case highRes = "High Res"
    }

    var visibleCount: Int { filteredEntries.count }
    var selectedCount: Int { filteredEntries.filter(\.isSelected).count }

    func load(url: String) async {
        isLoading = true
        do {
            let html = try await HTTPClient.shared.getString(url)
            let parsed = await HtmlParser.shared.parseDirectoryListing(html: html, baseURL: url)
            entries = parsed.map { entry in
                DirectoryItem(
                    name: entry.name,
                    url: entry.href,
                    type: entry.isDirectory ? .directory : DirectoryItemType.from(fileExtension: (entry.name as NSString).pathExtension),
                    size: entry.size,
                    sizeLabel: entry.sizeLabel,
                    isSelected: shouldAutoSelect(entry)
                )
            }
            applyFilter()
        } catch {
            AppLogger.error("Failed to load preview: \(error)")
        }
        isLoading = false
    }

    func applyFilter() {
        var result = entries
        if !filterText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
        }
        switch filterChip {
        case .all: break
        case .videos: result = result.filter { $0.type == .video }
        case .archives: result = result.filter { $0.type == .archive }
        case .hd: result = result.filter { $0.name.localizedCaseInsensitiveContains("1080") || $0.name.localizedCaseInsensitiveContains("bluray") }
        case .hd720: result = result.filter { $0.name.localizedCaseInsensitiveContains("720") }
        case .highRes: result = result.filter { $0.name.localizedCaseInsensitiveContains("2160") || $0.name.localizedCaseInsensitiveContains("4k") || $0.name.localizedCaseInsensitiveContains("bluray") }
        }
        filteredEntries = result
    }

    func toggleSelection(_ item: DirectoryItem) {
        guard let index = filteredEntries.firstIndex(where: { $0.id == item.id }) else { return }
        filteredEntries[index].isSelected.toggle()
        if let origIndex = entries.firstIndex(where: { $0.id == item.id }) {
            entries[origIndex].isSelected = filteredEntries[index].isSelected
        }
    }

    func selectAllFiltered() {
        for i in filteredEntries.indices { filteredEntries[i].isSelected = true }
        for entry in filteredEntries {
            if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[idx].isSelected = true
            }
        }
    }

    func deselectAll() {
        for i in filteredEntries.indices { filteredEntries[i].isSelected = false }
        for i in entries.indices { entries[i].isSelected = false }
    }

    func queueSelected() -> Int {
        var count = 0
        for item in entries where item.isSelected {
            DownloadManager.shared.addDownload(url: item.url, fileName: item.name)
            count += 1
        }
        return count
    }

    private func shouldAutoSelect(_ entry: ParsedEntry) -> Bool {
        let name = entry.name.lowercased()
        let ext = (name as NSString).pathExtension
        let videoExts = ["mp4", "mkv", "avi", "mov", "m4v", "webm"]
        let archiveExts = ["zip", "rar", "7z", "iso"]
        if videoExts.contains(ext) { return true }
        if archiveExts.contains(ext) { return true }
        if name.contains("1080") || name.contains("720") || name.contains("bluray") { return true }
        return false
    }
}

struct DownloadPreviewView: View {
    @State private var vm = DownloadPreviewViewModel()
    let url: String
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                chipBar

                if vm.isLoading {
                    Spacer()
                    ProgressView("Loading preview...")
                    Spacer()
                } else if vm.filteredEntries.isEmpty {
                    Spacer()
                    ContentUnavailableView("No Files", systemImage: "doc")
                    Spacer()
                } else {
                    List {
                        ForEach(vm.filteredEntries) { item in
                            HStack(spacing: 12) {
                                Image(systemName: vm.filteredEntries.first(where: { $0.id == item.id })?.isSelected == true ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isSelected ? .blue : .secondary)
                                    .onTapGesture { vm.toggleSelection(item) }

                                Image(systemName: item.type == .directory ? "folder" : "doc")
                                    .foregroundColor(.secondary)

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
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                HStack {
                    Text("\(vm.selectedCount) / \(vm.visibleCount) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        let count = vm.queueSelected()
                        if count > 0 { dismiss() }
                    } label: {
                        Label("Add to Queue (\(vm.selectedCount))", systemImage: "arrow.down.circle")
                            .font(.headline)
                    }
                    .disabled(vm.selectedCount == 0)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Select All Filtered") { vm.selectAllFiltered() }
                        Button("Deselect All") { vm.deselectAll() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { await vm.load(url: url) }
        }
    }

    private var filterBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Filter by name or regex...", text: $vm.filterText)
                .autocapitalization(.none)
                .onChange(of: vm.filterText) { _, _ in vm.applyFilter() }
            if !vm.filterText.isEmpty {
                Button { vm.filterText = ""; vm.applyFilter() } label: { Image(systemName: "xmark.circle.fill") }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DownloadPreviewViewModel.FilterChip.allCases, id: \.self) { chip in
                    Button(chip.rawValue) {
                        vm.filterChip = chip
                        vm.applyFilter()
                    }
                    .buttonStyle(.bordered)
                    .tint(vm.filterChip == chip ? .blue : .gray.opacity(0.3))
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}

private struct ParsedEntry {
    var name: String
    var href: String
    var isDirectory: Bool
    var sizeLabel: String
}
