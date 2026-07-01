import Fluent
import struct Foundation.UUID
import Foundation

final class Album: Model, @unchecked Sendable {
    static let schema = "albums"

    @ID(key: .id)
    var id: UUID?

    /// The album name
    @Field(key: "name")
    var name: String

    /// The MBID of the album, if available
    @Field(key: "mbid")
    var mbid: String?

    /// The URL for the album
    @Field(key: "url")
    var url: String

    /// The summary of the album, if available
    @Field(key: "summary")
    var summary: String?

    /// The biography of the album, if available
    @Field(key: "biography")
    var biography: String?

    /// The biography license (User-contributed text is available under the Creative Commons By-SA License; additional terms may apply. By default)
    @Field(key: "biography_license")
    var biographyLicense: String?

    /// When the biography was published, if available. Comes in this format: 17 Feb 2006, 22:09
    @Field(key: "published_date")
    var biographyPublished: Date?

    /// Total listeners the album has
    @Field(key: "listeners")
    var listeners: Int

    /// Total scrobbles the album has
    @Field(key: "scrobbles")
    var scrobbles: Int

    /// The artist of this album
    @Parent(key: "artist_id")
    var artist: Artist

    /// The cover image of the album
    @Parent(key: "cover_id")
    var cover: Cover

    /// The tags associated with the album
    @Siblings(through: AlbumTag.self, from: \.$album, to: \.$tag)
    var tags: [Tag]

    /// The tracks of this album
    @Children(for: \.$album)
    var tracks: [Track]

    /// When this album was created
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    /// When this album was last updated
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        name: String,
        mbid: String? = nil,
        url: String,
        summary: String? = nil,
        biography: String? = nil,
        biographyLicense: String? = nil,
        biographyPublished: Date? = nil,
        listeners: Int,
        scrobbles: Int,
        artistID: Artist.IDValue,
        coverID: Cover.IDValue
    ) {
        self.id = id
        self.name = name
        self.mbid = mbid
        self.url = url
        self.summary = summary
        self.biography = biography
        self.biographyLicense = biographyLicense
        self.biographyPublished = biographyPublished
        self.listeners = listeners
        self.scrobbles = scrobbles
        self.$artist.id = artistID
        self.$cover.id = coverID
    }
}
