import Foundation
import Vapor

actor PresenceStore {
    private var states: [String: PresenceStateDTO] = [:]
    private var subscribers: [String: [UUID: WebSocket]] = [:]

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func push(username: String, state: PresenceStateDTO) async {
        let key = username.lowercased()
        states[key] = state

        guard let sockets = subscribers[key], !sockets.isEmpty,
              let data = try? Self.encoder.encode(state) else { return }
        let text = String(decoding: data, as: UTF8.self)
        for socket in sockets.values {
            try? await socket.send(text)
        }
    }

    func latest(username: String, staleAfter: TimeInterval) -> PresenceStateDTO? {
        guard let state = states[username.lowercased()], Date().timeIntervalSince(state.updatedAt) < staleAfter else { return nil }
        return state
    }

    func subscribe(username: String, socket: WebSocket) -> UUID {
        let id = UUID()
        subscribers[username.lowercased(), default: [:]][id] = socket
        return id
    }

    func unsubscribe(username: String, id: UUID) {
        subscribers[username.lowercased()]?[id] = nil
    }
}

extension Application {
    private struct PresenceStoreKey: StorageKey {
        typealias Value = PresenceStore
    }

    var presence: PresenceStore {
        get {
            guard let store = storage[PresenceStoreKey.self] else {
                fatalError("No app.presence in configure.swift...")
            }
            return store
        }
        set { storage[PresenceStoreKey.self] = newValue }
    }
}
