import Foundation
import Vapor

struct PresenceInfoDTO: Content, Sendable {
    var title: String
    var artist: String
    var album: String?
    var durationSeconds: Int
    var elapsedTimeSeconds: Int
    var isPlaying: Bool
    var coverURL: String?
}

struct PresenceStateDTO: Content, Sendable {
    var device: String
    var info: PresenceInfoDTO?
    var updatedAt: Date
}

struct PresenceRegisterRequest: Content {
    var sessionKey: String
}

struct PresenceRegisterResponse: Content {
    var username: String
    var pushKey: String
}
