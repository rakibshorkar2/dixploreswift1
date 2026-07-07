import Foundation
import SwiftData

@MainActor
final class BookmarkRepository {
    static let shared = BookmarkRepository()

    private var context: ModelContext {
        DatabaseProvider.shared.context
    }

    private init() {}

    func getAll() -> [BookmarkEntity] {
        let descriptor = FetchDescriptor<BookmarkEntity>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func save(name: String, url: String) {
        let entity = BookmarkEntity(name: name, url: url)
        context.insert(entity)
        try? context.save()
    }

    func delete(id: String) {
        let descriptor = FetchDescriptor<BookmarkEntity>(predicate: #Predicate { $0.id == id })
        if let entity = try? context.fetch(descriptor).first {
            context.delete(entity)
            try? context.save()
        }
    }

    func deleteAll() {
        let items = getAll()
        for item in items {
            context.delete(item)
        }
        try? context.save()
    }

    func exists(url: String) -> Bool {
        let descriptor = FetchDescriptor<BookmarkEntity>(predicate: #Predicate { $0.url == url })
        return (try? context.fetch(descriptor).isEmpty == false) ?? false
    }
}
