import Foundation
import SwiftData

@MainActor
final class ProxyRepository {
    static let shared = ProxyRepository()

    private var context: ModelContext {
        DatabaseProvider.shared.context
    }

    private init() {}

    func getAll() -> [ProxyEntity] {
        let descriptor = FetchDescriptor<ProxyEntity>()
        return (try? context.fetch(descriptor)) ?? []
    }

    func save(protocolType: ProxyProtocol, host: String, port: Int, username: String = "", password: String = "") {
        let entity = ProxyEntity(protocolType: protocolType, host: host, port: port, username: username, password: password)
        context.insert(entity)
        try? context.save()
    }

    func update(_ entity: ProxyEntity) {
        try? context.save()
    }

    func delete(id: String) {
        let descriptor = FetchDescriptor<ProxyEntity>(predicate: #Predicate { $0.id == id })
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

    func getActiveProxy() -> ProxyEntity? {
        let descriptor = FetchDescriptor<ProxyEntity>(predicate: #Predicate { $0.isActive == true })
        return try? context.fetch(descriptor).first
    }

    func deactivateAll() {
        let items = getAll()
        for item in items {
            item.isActive = false
        }
        try? context.save()
    }

    func bulkImport(uris: [String]) {
        for uri in uris {
            if let proxy = ProxyModel.from(uri: uri) {
                save(protocolType: proxy.protocolType, host: proxy.host, port: proxy.port, username: proxy.username, password: proxy.password)
            }
        }
    }
}
