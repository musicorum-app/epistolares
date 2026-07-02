import Fluent
import struct Foundation.UUID
import Foundation

final class Cover: Model, @unchecked Sendable {
    struct Dimensions: Codable {
        let width: Int
        let height: Int

        static let small = Dimensions(width: 300, height: 300)
        static let medium = Dimensions(width: 500, height: 500)
        static let large = Dimensions(width: 1000, height: 1000)
    }

    enum CoverSource: String, Codable, CaseIterable {
        /// The cover is stored in the last.fm CDN
        case lastfm
    }

    static let schema = "covers"
    
    @ID(key: .id)
    var id: UUID?

    /// The source of the cover image
    @Field(key: "source")
    var source: CoverSource

    /// The external ID of the cover image.
    /// This is used to build the URL with the specified dimensions.
    @Field(key: "external_id")
    var externalID: String

    @Children(for: \.$cover)
    var artists: [Artist]

    @Children(for: \.$cover)
    var albums: [Album]

    @Children(for: \.$cover)
    var tracks: [Track]

    init() { }

    init(id: UUID? = nil, source: CoverSource, externalID: String) {
        self.id = id
        self.source = source
        self.externalID = externalID
    }

    func toCoverURL(dimensions: Dimensions) -> URL? {
        guard !externalID.isEmpty else { return nil }
        switch self.source {
        case .lastfm:
            return URL(string: "https://lastfm.freetls.fastly.net/i/u/\(dimensions.width)x\(dimensions.height)/\(self.externalID).jpg")!
        }
    }
}

