import SwiftUI

@Observable
@MainActor
final class TorrentViewModel {
    var searchQuery = ""
    var searchResults: [TorrentSearchResult] = []
    var activeTorrents: [TorrentItem] = []
    var isSearching = false
    var selectedProviders: Set<TorrentProvider> = Set(TorrentProvider.allCases.prefix(5))
    var selectedCategory: TorrentCategory = .all
    var showAddTorrent = false
    var showProviderPicker = false
    var clipboardMagnet: String?
    var showClipboardAlert = false

    func search() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        Task {
            let results = await TorrentSearchService.shared.search(
                query: searchQuery,
                providers: Array(selectedProviders),
                category: selectedCategory
            )
            searchResults = results
            isSearching = false
        }
    }

    func checkClipboard() {
        guard let pasteboard = UIPasteboard.general.string,
              pasteboard.hasPrefix("magnet:") || pasteboard.hasPrefix("magnet:?") else { return }
        if !activeTorrents.contains(where: { $0.magnetLink == pasteboard }) {
            clipboardMagnet = pasteboard
            showClipboardAlert = true
        }
    }

    func addMagnet(_ magnet: String) {
        TorrentEngine.shared.addMagnet(magnet)
        activeTorrents = TorrentEngine.shared.activeTorrents
        AppLogger.info("Added magnet: \(magnet)", category: .torrent)
    }
}

struct TorrentView: View {
    @State private var vm = TorrentViewModel()
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Search").tag(0)
                    Text("Active").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    searchView
                } else {
                    activeView
                }
            }
            .navigationTitle("Torrents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { vm.showAddTorrent = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $vm.showAddTorrent) { AddTorrentSheet() }
            .alert("Magnet Detected", isPresented: $vm.showClipboardAlert) {
                Button("Add") { vm.addMagnet(vm.clipboardMagnet ?? "") }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A magnet link was found in your clipboard. Would you like to add it?")
            }
            .onAppear { vm.checkClipboard() }
            .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                vm.checkClipboard()
            }
        }
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search torrents...", text: $vm.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .onSubmit { vm.search() }
                Button { vm.search() } label: { Image(systemName: "magnifyingglass").font(.title2) }
                    .disabled(vm.searchQuery.isEmpty)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TorrentCategory.allCases, id: \.self) { cat in
                        Button(cat.displayName) {
                            vm.selectedCategory = cat
                        }
                        .buttonStyle(.bordered)
                        .tint(vm.selectedCategory == cat ? .blue : .gray.opacity(0.3))
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            Button {
                vm.showProviderPicker = true
            } label: {
                HStack {
                    Text("\(vm.selectedProviders.count) providers selected")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.caption)
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            .sheet(isPresented: $vm.showProviderPicker) { ProviderPickerView(selected: $vm.selectedProviders) }

            if vm.isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if vm.searchResults.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Search across \(vm.selectedProviders.count) providers")
                )
                Spacer()
            } else {
                List {
                    ForEach(vm.searchResults) { result in
                        TorrentSearchRow(result: result)
                            .contextMenu {
                                Button { UIPasteboard.general.string = result.magnetLink } label: { Label("Copy Magnet", systemImage: "doc.on.doc") }
                                Button { vm.addMagnet(result.magnetLink) } label: { Label("Add Torrent", systemImage: "plus") }
                            }
                            .swipeActions(edge: .trailing) {
                                Button { vm.addMagnet(result.magnetLink) } label: { Label("Add", systemImage: "plus") }
                                    .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var activeView: some View {
        Group {
            if vm.activeTorrents.isEmpty {
                ContentUnavailableView(
                    "No Active Torrents",
                    systemImage: "arrow.down.circle",
                    description: Text("Add a magnet link to start downloading")
                )
            } else {
                List(vm.activeTorrents) { torrent in
                    TorrentRow(item: torrent)
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

struct TorrentSearchRow: View {
    let result: TorrentSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.body)
                .lineLimit(2)
            HStack(spacing: 12) {
                Label("\(result.seeders)", systemImage: "arrow.up")
                    .font(.caption)
                    .foregroundColor(.green)
                Label("\(result.leechers)", systemImage: "arrow.down")
                    .font(.caption)
                    .foregroundColor(.red)
                Text(result.size)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(result.provider)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TorrentRow: View {
    let item: TorrentItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
                statusIcon
            }
            ProgressView(value: item.progress)
                .tint(item.status == .downloading ? .blue : item.status == .paused ? .orange : .green)
            HStack {
                Text("\(item.progressPercent)%")
                    .font(.caption)
                    .fontWeight(.bold)
                Text(item.speedFormatted)
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
                Text(item.sizeFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var statusIcon: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIconName)
            Text(item.status.rawValue.capitalized)
                .font(.caption)
        }
        .foregroundColor(statusColor)
    }

    private var statusIconName: String {
        switch item.status {
        case .downloading: return "arrow.down.circle.fill"
        case .seeding: return "arrow.up.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .downloading: return .blue
        case .seeding: return .green
        case .paused: return .orange
        case .completed: return .green
        case .error: return .red
        }
    }
}

struct AddTorrentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var magnet = ""
    @State private var name = ""
    @State private var isSequential = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Magnet Link") {
                    TextEditor(text: $magnet)
                        .frame(minHeight: 80)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("Paste from Clipboard") {
                        magnet = UIPasteboard.general.string ?? ""
                    }
                    .font(.caption)
                }

                Section("Options") {
                    TextField("Name (optional)", text: $name)
                    Toggle("Sequential Download", isOn: $isSequential)
                }

                Section {
                    Button("Add Torrent") {
                        TorrentEngine.shared.addMagnet(magnet, name: name.isEmpty ? nil : name)
                        if !magnet.isEmpty {
                            UIPasteboard.general.string = ""
                        }
                        dismiss()
                    }
                    .disabled(magnet.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Add Torrent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ProviderPickerView: View {
    @Binding var selected: Set<TorrentProvider>

    var body: some View {
        NavigationStack {
            List(TorrentProvider.allCases, id: \.self) { provider in
                Button {
                    if selected.contains(provider) {
                        selected.remove(provider)
                    } else {
                        selected.insert(provider)
                    }
                } label: {
                    HStack {
                        Text(provider.displayName)
                        Spacer()
                        if selected.contains(provider) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Search Providers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
