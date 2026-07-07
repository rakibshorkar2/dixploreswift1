import Foundation
import SwiftData

@MainActor
final class DownloadRepository {
    static let shared = DownloadRepository()

    private var context: ModelContext {
        DatabaseProvider.shared.context
    }

    private init() {}

    func getAll() -> [DownloadEntity] {
        let descriptor = FetchDescriptor<DownloadEntity>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func get(id: String) -> DownloadEntity? {
        let descriptor = FetchDescriptor<DownloadEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    func save(_ entity: DownloadEntity) {
        context.insert(entity)
        try? context.save()
    }

    func update(_ entity: DownloadEntity) {
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

    func getActive() -> [DownloadEntity] {
        let descriptor = FetchDescriptor<DownloadEntity>(
            predicate: #Predicate { $0.statusRaw == DownloadStatus.downloading.rawValue || $0.statusRaw == DownloadStatus.queued.rawValue },
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func getCompleted() -> [DownloadEntity] {
        let descriptor = FetchDescriptor<DownloadEntity>(
            predicate: #Predicate { $0.statusRaw == DownloadStatus.done.rawValue },
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func deleteCompleted() {
        let completed = getCompleted()
        for item in completed {
            context.delete(item)
        }
        try? context.save()
    }
}
