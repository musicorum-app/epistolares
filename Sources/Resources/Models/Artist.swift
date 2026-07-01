import Fluent
import struct Foundation.UUID
import Foundation

final class Artist: Model, @unchecked Sendable {
    static let schema = "artists"
    
    @ID(key: .id)
    var id: UUID?

    /// The artist name
    @Field(key: "name")
    var name: String

    /// Other names for the artist. These are appended as API calls to Last.fm are made and the name doesn't match the artist name or any of the saved aliases.
    @Field(key: "aliases")
    var aliases: [String]

    /// The MBID of the artist, if available
    @Field(key: "mbid")
    var mbid: String?

    /// The URL for the artist
    @Field(key: "url")
    var url: String

    /// The summary of the artist, if available
    @Field(key: "summary")
    var summary: String?

    /// The biography of the artist, if available
    @Field(key: "biography")
    var biography: String?

    /// The biography license (User-contributed text is available under the Creative Commons By-SA License; additional terms may apply. By default)
    @Field(key: "biography_license")
    var biographyLicense: String?

    /// When the biography was published, if available. Comes in this format: 17 Feb 2006, 22:09
    @Field(key: "formed_date")
    var biographyPublished: Date?
    
    /// The tags associated with the artist
    @Siblings(through: ArtistTag.self, from: \.$artist, to: \.$tag)
    var tags: [Tag]

    /// The external ID of the cover image.
    /// This is used to build the URL with the specified dimensions.
    @Field(key: "external_id")
    var externalID: String

    /// Total listeners the artist has
    @Field(key: "listeners")
    var listeners: Int

    /// Total scrobbles the artist has
    @Field(key: "scrobbles")
    var scrobbles: Int

    /// The cover image of the artist
    @Parent(key: "cover_id")
    var cover: Cover

    /// Similar artists to this artist
    @Siblings(through: SimilarArtists.self, from: \.$artist, to: \.$similarArtist)
    var similarArtists: [Artist]

    /// When this artist was last updated
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    /// When this artist was last updated
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init () { }

    init(
        id: UUID? = nil,
        name: String,
        aliases: [String] = [],
        mbid: String? = nil,
        url: String,
        summary: String? = nil,
        biography: String? = nil,
        biographyLicense: String? = nil,
        biographyPublished: Date? = nil,
        externalID: String,
        listeners: Int,
        scrobbles: Int,
        coverID: Cover.IDValue
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.mbid = mbid
        self.url = url
        self.summary = summary
        self.biography = biography
        self.biographyLicense = biographyLicense
        self.biographyPublished = biographyPublished
        self.externalID = externalID
        self.listeners = listeners
        self.scrobbles = scrobbles
        self.$cover.id = coverID
    }
}

