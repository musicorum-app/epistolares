import Foundation

/// TODO: redis support
actor InMemoryCache<Key: Hashable & Sendable, Value: Sendable> {
    private var store: [Key: (expires: Date, value: Value)] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    func get(_ key: Key) -> Value? {
        guard let entry = store[key], entry.expires > Date() else { return nil }
        return entry.value
    }

    func set(_ key: Key, _ value: Value) {
        store[key] = (Date().addingTimeInterval(ttl), value)
    }
}
