import Fluent
import struct Foundation.UUID
import Foundation

final class Tag: Model, @unchecked Sendable {
    static let schema = "tags"
    
    @ID(key: .id)
    var id: UUID?

    /// The name of the tag
    @Field(key: "name")
    var name: String

    /// The URL for the tag
    @Field(key: "url")
    var url: String

    /// Artists that have this tag
    @Siblings(through: ArtistTag.self, from: \.$tag, to: \.$artist)
    var artists: [Artist]

    /// Albums that have this tag
    @Siblings(through: AlbumTag.self, from: \.$tag, to: \.$album)
    var albums: [Album]

    /// Tracks that have this tag
    @Siblings(through: TrackTag.self, from: \.$tag, to: \.$track)
    var tracks: [Track]

    init() { }

    init(id: UUID? = nil, name: String, url: String) {
        self.id = id
        self.name = name
        self.url = url
    }
}
