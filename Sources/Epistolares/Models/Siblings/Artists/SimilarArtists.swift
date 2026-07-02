import Fluent
import struct Foundation.UUID
import Foundation

final class SimilarArtists: Model, @unchecked Sendable {
    static let schema = "similar_artists"
    
    @ID(key: .id)
    var id: UUID?

    /// The artist that the similar artists are associated with
    @Parent(key: "artist_id")
    var artist: Artist

    /// The similar artists
    @Parent(key: "similar_artist_id")
    var similarArtist: Artist

    init() { }

    init(id: UUID? = nil, artist: Artist, similarArtist: Artist) {
        self.id = id
        self.$artist.id = artist.id!
        self.$similarArtist.id = similarArtist.id!
    }
}
