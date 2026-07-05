import SwiftUI

struct BrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()
    @State private var showBookmarks = false
    @State private var showAddBookmark = false
    @State private var bookmarkTitle = ""
    @State private var showSearch = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                urlBar
                searchBar
                contentArea
            }
            .navigationTitle("Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        Button(action: { viewModel.goBack() }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!viewModel.canGoBack)

                        Button(action: { viewModel.goForward() }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!viewModel.canGoForward)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showSearch.toggle() }) {
                        Image(systemName: "magnifyingglass")
                    }
                    Button(action: { viewModel.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button(action: { showBookmarks.toggle() }) {
                        Image(systemName: "bookmark")
                    }
                }
            }
            .sheet(isPresented: $showBookmarks) {
                bookmarksView
            }
            .alert("Add Bookmark", isPresented: $showAddBookmark) {
                TextField("Title", text: $bookmarkTitle)
                Button("Save") {
                    viewModel.addBookmark(title: bookmarkTitle, url: viewModel.currentURL)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("URL: \(viewModel.currentURL)")
            }
        }
    }

    private var urlBar: some View {
        HStack {
            Image(systemName: viewModel.currentURL.hasPrefix("https") ? "lock.fill" : "lock.open")
                .foregroundColor(viewModel.currentURL.hasPrefix("https") ? .green : .gray)
                .font(.caption)

            TextField("Enter URL...", text: $viewModel.currentURL)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }

            Button(action: {
                viewModel.navigateToURL(viewModel.currentURL)
                hideKeyboard()
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchBar: some View {
        Group {
            if showSearch {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search files...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: showSearch)
            }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if let error = viewModel.errorMessage {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    viewModel.refresh()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            Spacer()
        } else if viewModel.isLoading && viewModel.directoryEntries.isEmpty {
            Spacer()
            ProgressView("Loading...")
            Spacer()
        } else if viewModel.directoryEntries.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Enter a URL to browse")
                    .foregroundColor(.secondary)
                Text("e.g. http://172.16.50.4")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            Spacer()
        } else {
            List {
                ForEach(viewModel.filteredEntries) { entry in
                    Button(action: { viewModel.openEntry(entry) }) {
                        HStack(spacing: 12) {
                            Image(systemName: entry.isDirectory ? "folder" : "doc")
                                .foregroundColor(entry.isDirectory ? .blue : .secondary)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                if !entry.isDirectory {
                                    Text(entry.formattedSize)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contextMenu {
                        if !entry.isDirectory {
                            Button(action: { viewModel.openEntry(entry) }) {
                                Label("Download", systemImage: "arrow.down.circle")
                            }
                        }
                        Button(action: {
                            bookmarkTitle = entry.name
                            showAddBookmark = true
                        }) {
                            Label("Bookmark", systemImage: "bookmark")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                viewModel.refresh()
            }
        }
    }

    private var bookmarksView: some View {
        NavigationView {
            List {
                if viewModel.bookmarks.isEmpty {
                    Text("No bookmarks yet")
                        .foregroundColor(.secondary)
                }
                ForEach(viewModel.bookmarks) { bookmark in
                    Button(action: {
                        viewModel.currentURL = bookmark.url
                        viewModel.navigateToURL(bookmark.url)
                        showBookmarks = false
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bookmark.title)
                                .foregroundColor(.primary)
                            Text(bookmark.url)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .onDelete(perform: viewModel.removeBookmark)
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                       to: nil, from: nil, for: nil)
    }
}
