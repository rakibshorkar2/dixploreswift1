import Foundation
import SwiftData

@MainActor
final class TorrentRepository {
    static let shared = TorrentRepository()

    private var context: ModelContext {
        DatabaseProvider.shared.context
    }

    private init() {}

    func getAll() -> [TorrentEntity] {
        let descriptor = FetchDescriptor<TorrentEntity>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func get(id: String) -> TorrentEntity? {
        let descriptor = FetchDescriptor<TorrentEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    func save(_ entity: TorrentEntity) {
        context.insert(entity)
        try? context.save()
    }

    func update(_ entity: TorrentEntity) {
        try? context.save()
    }

    func delete(id: String) {
        guard let entity = get(id: id) else { return }
        context.delete(entity)
        try? context.save()
    }

    func deleteAll() {
        let items = getAll()
        for item in items {
            context.delete(item)
        }
        try? context.save()
    }
}
