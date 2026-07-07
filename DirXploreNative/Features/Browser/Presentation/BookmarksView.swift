import SwiftUI

struct BookmarksView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var bookmarks: [BookmarkEntity] = []
    @State private var showAddBookmark = false
    @State private var newName = ""
    @State private var newURL = ""

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Bookmark directories for quick access")
                    )
                } else {
                    List {
                        ForEach(bookmarks, id: \.id) { bookmark in
                            Button {
                                onSelect(bookmark.url)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.name)
                                        .font(.body)
                                    Text(bookmark.url)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    BookmarkRepository.shared.delete(id: bookmark.id)
                                    loadBookmarks()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddBookmark = true } label: { Image(systemName: "plus") }
                }
            }
            .onAppear { loadBookmarks() }
            .sheet(isPresented: $showAddBookmark) {
                NavigationStack {
                    Form {
                        TextField("Name", text: $newName)
                        TextField("URL", text: $newURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                        Button("Add") {
                            BookmarkRepository.shared.save(name: newName, url: newURL)
                            loadBookmarks()
                            showAddBookmark = false
                            newName = ""
                            newURL = ""
                        }
                        .disabled(newName.isEmpty || newURL.isEmpty)
                    }
                    .navigationTitle("Add Bookmark")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddBookmark = false }
                        }
                    }
                }
            }
        }
    }

    private func loadBookmarks() {
        bookmarks = BookmarkRepository.shared.getAll()
    }
}
