import Fluent
import struct Foundation.UUID
import Foundation

final class ArtistTag: Model, @unchecked Sendable {
    static let schema = "artist_tags"
    
    @ID(key: .id)
    var id: UUID?

    /// The artist that the tag is associated with
    @Parent(key: "artist_id")
    var artist: Artist

    /// The tag that is associated with the artist
    @Parent(key: "tag_id")
    var tag: Tag

    init() { }

    init(id: UUID? = nil, artist: Artist, tag: Tag) {
        self.id = id
        self.$artist.id = artist.id!
        self.$tag.id = tag.id!
    }
}