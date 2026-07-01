import Fluent
import struct Foundation.UUID
import Foundation

final class AlbumTag: Model, @unchecked Sendable {
    static let schema = "album_tags"
    
    @ID(key: .id)
    var id: UUID?

    /// The album that the tag is associated with
    @Parent(key: "album_id")
    var album: Album

    /// The tag that is associated with the album
    @Parent(key: "tag_id")
    var tag: Tag

    init() { }

    init(id: UUID? = nil, album: Album, tag: Tag) {
        self.id = id
        self.$album.id = album.id!
        self.$tag.id = tag.id!
    }
}