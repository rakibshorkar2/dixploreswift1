import SwiftUI

struct DownloadsView: View {
    @State private var dm = DownloadManager.shared
    @State private var showNewDownload = false
    @State private var showExport = false
    @State private var showImport = false
    @State private var showClearConfirmation = false
    @State private var selectionMode = false
    @State private var selectedIds: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                storageBar

                if dm.downloads.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Tap + to add a download")
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(groupedBatches.keys.sorted(by: >), id: \.self) { batch in
                            if let items = groupedBatches[batch] {
                                Section {
                                    ForEach(items) { item in
                                        DownloadRow(item: item, selectionMode: selectionMode, isSelected: selectedIds.contains(item.id)) {
                                            if selectionMode {
                                                toggleSelection(item.id)
                                            }
                                        }
                                        .contextMenu { downloadContextMenu(item) }
                                        .swipeActions(edge: .trailing) {
                                            swipeActions(item)
                                        }
                                    }
                                } header: {
                                    if !batch.isEmpty {
                                        BatchHeader(batchName: batch, items: items)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !dm.downloads.isEmpty {
                        Button(selectionMode ? "Done" : "Select") {
                            selectionMode.toggle()
                            if !selectionMode { selectedIds.removeAll() }
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if selectionMode {
                        Button("Delete", role: .destructive) { deleteSelected() }
                            .disabled(selectedIds.isEmpty)
                    } else {
                        Menu {
                            Button { showNewDownload = true } label: { Label("New Download", systemImage: "plus") }
                            Button { dm.pauseAll() } label: { Label("Pause All", systemImage: "pause") }
                            Button { dm.resumeAll() } label: { Label("Resume All", systemImage: "play") }
                            Divider()
                            Button { showExport = true } label: { Label("Export Queue", systemImage: "square.and.arrow.up") }
                            Button { showImport = true } label: { Label("Import Queue", systemImage: "square.and.arrow.down") }
                            Divider()
                            Button(role: .destructive) { showClearConfirmation = true } label: { Label("Clear Completed", systemImage: "trash") }
                            Button(role: .destructive) { dm.clearAll() } label: { Label("Clear All", systemImage: "trash.fill") }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showNewDownload = true
                    } label: {
                        Label("New Download", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showNewDownload) { NewDownloadSheet() }
            .sheet(isPresented: $showExport) {
                ActivityView(activityItems: [dm.exportQueue() as Any])
            }
            .sheet(isPresented: $showImport) {
                DocumentPickerView(contentTypes: [.json]) { url in
                    dm.importQueue(from: url)
                }
            }
            .sheet(isPresented: $showHashVerification) {
                if let item = hashVerificationItem {
                    HashVerificationView(fileURL: URL(fileURLWithPath: item.savePath), fileName: item.fileName)
                }
            }
            .sheet(isPresented: $showQuickLook) {
                if let item = quickLookItem {
                    QuickLookView(url: URL(fileURLWithPath: item.savePath))
                }
            }
            .alert("Clear Completed", isPresented: $showClearConfirmation) {
                Button("Clear", role: .destructive) { dm.clearCompleted() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove all completed downloads from the list.")
            }
        }
    }

    private var storageBar: some View {
        let total = UIDevice.current.totalDiskSpace
        let free = UIDevice.current.freeDiskSpace
        let used = total - free
        let percent = total > 0 ? Double(used) / Double(total) : 0

        return VStack(spacing: 4) {
            ProgressView(value: percent)
                .tint(percent > 0.9 ? .red : percent > 0.7 ? .orange : .blue)
            HStack {
                Text("Used: \(used.fileSizeFormatted)")
                    .font(.caption2)
                Spacer()
                Text("Free: \(free.fileSizeFormatted)")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var groupedBatches: [String: [DownloadItem]] {
        Dictionary(grouping: dm.downloads) { $0.batchId ?? $0.id }
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) { selectedIds.remove(id) }
        else { selectedIds.insert(id) }
    }

    private func deleteSelected() {
        for id in selectedIds { dm.deleteDownload(id: id, deleteFile: true) }
        selectedIds.removeAll()
        selectionMode = false
    }

    @State private var showHashVerification = false
    @State private var hashVerificationItem: DownloadItem?
    @State private var showQuickLook = false
    @State private var quickLookItem: DownloadItem?

    @ViewBuilder
    private func downloadContextMenu(_ item: DownloadItem) -> some View {
        switch item.status {
        case .downloading:
            Button { dm.pauseDownload(downloadId: item.id) } label: { Label("Pause", systemImage: "pause") }
            Divider()
        case .paused:
            Button { dm.resumeDownload(downloadId: item.id) } label: { Label("Resume", systemImage: "play") }
            Button { dm.restartDownload(downloadId: item.id) } label: { Label("Restart", systemImage: "arrow.counterclockwise") }
            Divider()
        case .error:
            Button { dm.retryDownload(downloadId: item.id) } label: { Label("Retry", systemImage: "arrow.clockwise") }
            Button { dm.restartDownload(downloadId: item.id) } label: { Label("Restart from Scratch", systemImage: "arrow.counterclockwise") }
            Divider()
        case .queued:
            Button { dm.cancelDownload(downloadId: item.id) } label: { Label("Cancel", systemImage: "xmark") }
            Divider()
        case .done:
            Button { quickLookItem = item; showQuickLook = true } label: { Label("Quick Look", systemImage: "eye") }
            Button { shareFile(item) } label: { Label("Share", systemImage: "square.and.arrow.up") }
            Button { saveToFiles(item) } label: { Label("Save to Files", systemImage: "folder") }
            Divider()
            Button { hashVerificationItem = item; showHashVerification = true } label: { Label("Verify File Hash", systemImage: "checkmark.shield") }
            Divider()
        }
        priorityMenu(item)
        Divider()
        Button(role: .destructive) { dm.deleteDownload(id: item.id, deleteFile: true) } label: { Label("Delete with File", systemImage: "trash") }
        Button(role: .destructive) { dm.deleteDownload(id: item.id) } label: { Label("Remove from List", systemImage: "trash.slash") }
    }

    @ViewBuilder
    private func priorityMenu(_ item: DownloadItem) -> some View {
        Menu {
            ForEach(DownloadPriority.allCases, id: \.self) { priority in
                Button {
                    dm.setPriority(downloadId: item.id, priority: priority)
                } label: {
                    HStack {
                        Text(priority.label)
                        if item.priority == priority {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Priority: \(item.priority.label)", systemImage: "line.horizontal.star.fill.line.horizontal")
        }
    }

    @ViewBuilder
    private func swipeActions(_ item: DownloadItem) -> some View {
        if item.status == .downloading {
            Button { dm.pauseDownload(downloadId: item.id) } label: { Label("Pause", systemImage: "pause") }
                .tint(.orange)
        } else if item.status == .paused || item.status == .error {
            Button { dm.resumeDownload(downloadId: item.id) } label: { Label("Resume", systemImage: "play") }
                .tint(.green)
        }
        Button(role: .destructive) { dm.deleteDownload(id: item.id) } label: { Label("Delete", systemImage: "trash") }
    }

    private func shareFile(_ item: DownloadItem) {
        let url = URL(fileURLWithPath: item.savePath)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.keyWindow?.rootViewController else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(activityVC, animated: true)
    }

    private func saveToFiles(_ item: DownloadItem) {
        let url = URL(fileURLWithPath: item.savePath)
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.keyWindow?.rootViewController else { return }
        root.present(picker, animated: true)
    }
}

struct DownloadRow: View {
    let item: DownloadItem
    let selectionMode: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(.body)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        statusBadge
                        priorityBadge
                        if item.status == .downloading {
                            Text(item.speedFormatted)
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(item.etaFormatted)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if item.status == .downloading || item.status == .paused {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.progressPercent)%")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("\(item.downloadedFormatted) / \(item.totalSizeFormatted)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if item.status == .done {
                    Text(item.totalSizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption2)
            Text(item.status.label)
                .font(.caption2)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.1))
        .cornerRadius(4)
    }

    private var statusIcon: String {
        switch item.status {
        case .queued: return "clock"
        case .downloading: return "arrow.down.circle"
        case .paused: return "pause.circle"
        case .error: return "exclamationmark.circle"
        case .done: return "checkmark.circle"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .queued: return .gray
        case .downloading: return .blue
        case .paused: return .orange
        case .error: return .red
        case .done: return .green
        }
    }

    @ViewBuilder
    private var priorityBadge: some View {
        if item.priority != .normal {
            Text(item.priority.label.prefix(4))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(priorityColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(priorityColor.opacity(0.1))
                .cornerRadius(3)
        }
    }

    private var priorityColor: Color {
        switch item.priority {
        case .high: return .red
        case .normal: return .clear
        case .low: return .gray
        }
    }
}

struct BatchHeader: View {
    let batchName: String
    let items: [DownloadItem]

    var body: some View {
        HStack {
            Text(batchName)
                .font(.headline)
            Spacer()
            let total = items.count
            let done = items.filter { $0.status == .done }.count
            let progress = items.map(\.progress).reduce(0, +) / Double(max(total, 1))
            Text("\(done)/\(total) - \(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NewDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @State private var fileName = ""
    @State private var isLoading = false
    @State private var metadata: [String: String] = [:]
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("URL") {
                    TextField("https://example.com/file.zip", text: $urlString)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)

                    Button("Paste from Clipboard") {
                        urlString = UIPasteboard.general.string ?? ""
                    }
                    .font(.caption)
                }

                Section("File Info") {
                    TextField("Filename", text: $fileName)
                        .autocapitalization(.none)

                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Fetching metadata...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !metadata.isEmpty {
                        Group {
                            if let type = metadata["content-type"] {
                                LabeledContent("Type", value: type)
                            }
                            if let length = metadata["content-length"], let bytes = Int64(length) {
                                LabeledContent("Size", value: bytes.fileSizeFormatted)
                            }
                            if let ranges = metadata["accept-ranges"] {
                                LabeledContent("Resume", value: ranges == "bytes" ? "Supported" : "Not supported")
                            }
                        }
                        .font(.caption)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button("Fetch Metadata") {
                        fetchMetadata()
                    }
                    .disabled(urlString.isEmpty || isLoading)

                    Button("Download") {
                        startDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlString.isEmpty || fileName.isEmpty)
                }
            }
            .navigationTitle("New Download")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func fetchMetadata() {
        isLoading = true
        errorMessage = nil
        var url = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
            urlString = url
        }
        Task {
            do {
                let meta = try await HTTPClient.shared.headMetadata(url)
                metadata = meta
                if fileName.isEmpty {
                    if let disposition = meta["content-disposition"] {
                        let parts = disposition.components(separatedBy: "filename=")
                        if parts.count > 1 {
                            fileName = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                        }
                    }
                }
                if fileName.isEmpty {
                    fileName = URL(string: url)?.lastPathComponent ?? "download"
                }
            } catch {
                errorMessage = error.localizedDescription
                if fileName.isEmpty {
                    fileName = URL(string: url)?.lastPathComponent ?? "download"
                }
            }
            isLoading = false
        }
    }

    private func startDownload() {
        var url = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }
        DownloadManager.shared.addDownload(url: url, fileName: fileName)
        dismiss()
    }
}
