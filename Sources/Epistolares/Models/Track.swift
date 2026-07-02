import Fluent
import struct Foundation.UUID
import Foundation

final class Track: Model, @unchecked Sendable {
    static let schema = "tracks"

    @ID(key: .id)
    var id: UUID?

    /// The track name
    @Field(key: "name")
    var name: String

    /// The MBID of the track, if available
    @Field(key: "mbid")
    var mbid: String?

    /// The URL for the track
    @Field(key: "url")
    var url: String

    /// The track's duration, in seconds
    @Field(key: "duration")
    var duration: Int

    /// The track's position in the album
    @Field(key: "rank")
    var rank: Int

    /// Total listeners the track has
    @Field(key: "listeners")
    var listeners: Int

    /// Total scrobbles the track has
    @Field(key: "scrobbles")
    var scrobbles: Int

    /// The artist of this track
    @Parent(key: "artist_id")
    var artist: Artist

    /// The album this track belongs to
    @Parent(key: "album_id")
    var album: Album

    /// The cover image of the track
    @Parent(key: "cover_id")
    var cover: Cover

    /// The tags associated with the track
    @Siblings(through: TrackTag.self, from: \.$track, to: \.$tag)
    var tags: [Tag]

    /// When this track was created
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    /// When this track was last updated
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        name: String,
        mbid: String? = nil,
        url: String,
        duration: Int,
        rank: Int,
        listeners: Int,
        scrobbles: Int,
        artistID: Artist.IDValue,
        albumID: Album.IDValue,
        coverID: Cover.IDValue
    ) {
        self.id = id
        self.name = name
        self.mbid = mbid
        self.url = url
        self.duration = duration
        self.rank = rank
        self.listeners = listeners
        self.scrobbles = scrobbles
        self.$artist.id = artistID
        self.$album.id = albumID
        self.$cover.id = coverID
    }
}
