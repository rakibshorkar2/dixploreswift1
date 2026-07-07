import Foundation

@globalActor actor AppActor {
    static let shared = AppActor()
}

protocol Resolver: AnyObject {
    func resolve<T>(_ type: T.Type) -> T?
}

final class DependencyContainer: Resolver {
    static let shared = DependencyContainer()

    private var services: [ObjectIdentifier: Any] = [:]
    private let lock = NSLock()

    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.withLock {
            services[ObjectIdentifier(type)] = factory
        }
    }

    func registerSingleton<T>(_ type: T.Type, instance: T) {
        lock.withLock {
            services[ObjectIdentifier(type)] = instance
        }
    }

    func resolve<T>(_ type: T.Type) -> T? {
        lock.withLock {
            guard let factory = services[ObjectIdentifier(type)] as? () -> T else {
                return services[ObjectIdentifier(type)] as? T
            }
            return factory()
        }
    }

    func resolve<T>() -> T? {
        resolve(T.self)
    }
}
