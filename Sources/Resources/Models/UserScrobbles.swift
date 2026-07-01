import Fluent
import struct Foundation.UUID
import Foundation

final class UserScrobbles: Model, @unchecked Sendable {
    static let schema = "user_scrobbles"

    @ID(key: .id)
    var id: UUID?

    /// The Last.fm username, always stored lowercased
    @Field(key: "username")
    private var _username: String
    var username: String {
        get { _username }
        set { _username = newValue.lowercased() }
    }

    /// How many times this user scrobbled the entity
    @Field(key: "play_count")
    var playCount: Int

    /// Whether the user loved this track. Only present when the entity is a track
    @Field(key: "loved")
    var loved: Bool?

    /// The artist this scrobble is for, if any
    @OptionalParent(key: "artist_id")
    var artist: Artist?

    /// The album this scrobble is for, if any
    @OptionalParent(key: "album_id")
    var album: Album?

    /// The track this scrobble is for, if any
    @OptionalParent(key: "track_id")
    var track: Track?

    /// When this scrobble entry was created
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    /// When this scrobble entry was last updated
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        username: String,
        playCount: Int,
        loved: Bool? = nil,
        artistID: Artist.IDValue? = nil,
        albumID: Album.IDValue? = nil,
        trackID: Track.IDValue? = nil
    ) {
        self.id = id
        self._username = username.lowercased()
        self.playCount = playCount
        self.loved = loved
        self.$artist.id = artistID
        self.$album.id = albumID
        self.$track.id = trackID
    }

    static func query(forUsername username: String, on database: any Database) -> QueryBuilder<UserScrobbles> {
        UserScrobbles.query(on: database).filter(\.$_username == username.lowercased())
    }
}
