import SwiftUI

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @State private var selectedIds = Set<UUID>()
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.activeDownloads.isEmpty && viewModel.finishedDownloads.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No downloads")
                            .foregroundColor(.secondary)
                        Text("Download files from the browser tab")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()
                } else {
                    List {
                        if !viewModel.activeDownloads.isEmpty {
                            Section("Active") {
                                ForEach(viewModel.activeDownloads) { item in
                                    DownloadRow(item: item)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                viewModel.cancelDownload(id: item.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                if item.status == .paused {
                                                    viewModel.resumeDownload(id: item.id)
                                                } else {
                                                    viewModel.pauseDownload(id: item.id)
                                                }
                                            } label: {
                                                Label(item.status == .paused ? "Resume" : "Pause",
                                                      systemImage: item.status == .paused ? "play" : "pause")
                                            }
                                            .tint(.orange)
                                        }
                                }
                            }
                        }

                        if !viewModel.pausedDownloads.isEmpty {
                            Section("Paused") {
                                ForEach(viewModel.pausedDownloads) { item in
                                    DownloadRow(item: item)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                viewModel.cancelDownload(id: item.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                viewModel.resumeDownload(id: item.id)
                                            } label: {
                                                Label("Resume", systemImage: "play")
                                            }
                                            .tint(.green)
                                        }
                                }
                            }
                        }

                        if !viewModel.finishedDownloads.isEmpty {
                            Section("Completed") {
                                ForEach(viewModel.finishedDownloads) { item in
                                    DownloadRow(item: item)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                viewModel.deleteDownload(id: item.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !viewModel.activeDownloads.isEmpty {
                        Menu {
                            Button(action: { viewModel.pauseAll() }) {
                                Label("Pause All", systemImage: "pause")
                            }
                            Button(action: { viewModel.resumeAll() }) {
                                Label("Resume All", systemImage: "play")
                            }
                            Button(role: .destructive, action: { viewModel.cancelAll() }) {
                                Label("Cancel All", systemImage: "xmark")
                            }
                            Divider()
                            Button(role: .destructive, action: { viewModel.deleteAllCompleted() }) {
                                Label("Delete All Completed", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
}

struct DownloadRow: View {
    let item: DownloadTaskItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename)
                    .lineLimit(1)
                    .font(.subheadline)

                if item.status == .downloading {
                    ProgressView(value: item.progress)
                        .tint(.blue)
                    Text("\(Int(item.progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if item.status == .paused {
                    Text("Paused - \(Int(item.progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else if item.status == .completed {
                    Text("Completed")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else if item.status == .failed {
                    Text("Failed")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            if item.status == .downloading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch item.status {
        case .downloading: return "arrow.down.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.circle"
        case .pending: return "clock"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .downloading: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        case .pending: return .gray
        }
    }
}
