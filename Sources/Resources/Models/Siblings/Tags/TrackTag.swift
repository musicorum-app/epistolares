import Fluent
import struct Foundation.UUID
import Foundation

final class TrackTag: Model, @unchecked Sendable {
    static let schema = "track_tags"
    
    @ID(key: .id)
    var id: UUID?

    /// The track that the tag is associated with
    @Parent(key: "track_id")
    var track: Track

    /// The tag that is associated with the track
    @Parent(key: "tag_id")
    var tag: Tag

    init() { }

    init(id: UUID? = nil, track: Track, tag: Tag) {
        self.id = id
        self.$track.id = track.id!
        self.$tag.id = tag.id!
    }
}