import Foundation

protocol UseCase {
    associatedtype Input
    associatedtype Output
    func execute(_ input: Input) async throws -> Output
}

protocol VoidUseCase {
    associatedtype Output
    func execute() async throws -> Output
}

protocol Repository {
    associatedtype Entity
    associatedtype Identifier

    func get(id: Identifier) async throws -> Entity?
    func getAll() async throws -> [Entity]
    func save(_ entity: Entity) async throws
    func delete(id: Identifier) async throws
    func deleteAll() async throws
}
