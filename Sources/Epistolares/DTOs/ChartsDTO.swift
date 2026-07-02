import Foundation
import Vapor

enum ChartType: String, Content, CaseIterable, Sendable {
    case artist
    case album
    case track
}

enum ChartPeriod: String, Content, CaseIterable, Sendable {
    case overall
    case sevenDay = "7day"
    case oneMonth = "1month"
    case threeMonth = "3month"
    case sixMonth = "6month"
    case twelveMonth = "12month"
}

struct ChartsQuery: Content {
    var username: String
    var type: ChartType
    var period: ChartPeriod
    var limit: Int?
    var page: Int?
}

struct ChartsAllQuery: Content {
    var username: String
    var period: ChartPeriod
    var limit: Int?
}

struct ChartEntryDTO: Content, Sendable {
    var id: UUID
    var name: String
    var artist: String?
    var cover: CoverDTO?
    var playCount: Int
}

struct ChartsResponseDTO: Content, Sendable {
    var page: Int
    var totalPages: Int
    var total: Int
    var items: [ChartEntryDTO]
}

struct ChartsAllResponseDTO: Content, Sendable {
    var artists: ChartsResponseDTO
    var albums: ChartsResponseDTO
    var tracks: ChartsResponseDTO
}
