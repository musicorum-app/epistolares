@testable import Epistolares
import Testing
import Foundation

@Suite("LFM model decoding quirks")
struct LFMModelsTests {
    @Test("LFMIntString decodes a JSON string number")
    func decodesStringNumber() throws {
        let json = #"{"value": "1193053"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: LFMIntString].self, from: json)
        #expect(decoded["value"]?.value == 1193053)
    }

    @Test("LFMIntString decodes a real JSON number")
    func decodesRealNumber() throws {
        let json = #"{"value": 254}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: LFMIntString].self, from: json)
        #expect(decoded["value"]?.value == 254)
    }

    @Test("LFMTagsWrapper decodes a real tag list")
    func decodesTagList() throws {
        let json = #"{"tag": [{"name": "rnb", "url": "https://www.last.fm/tag/rnb"}]}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LFMTagsWrapper.self, from: json)
        #expect(decoded.tag?.map(\.name) == ["rnb"])
    }

    @Test("LFMTagsWrapper tolerates a single tag collapsed to a bare object")
    func decodesSingleTagObject() throws {
        let json = #"{"tag": {"name": "rnb", "url": "https://www.last.fm/tag/rnb"}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LFMTagsWrapper.self, from: json)
        #expect(decoded.tag?.map(\.name) == ["rnb"])
    }

    @Test("LFMTagsWrapper tolerates Last.fm's empty-string tags field")
    func decodesEmptyStringTags() throws {
        let json = #""""#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LFMTagsWrapper.self, from: json)
        #expect(decoded.tag == nil)
    }

    @Test("LFMList decodes a real array")
    func decodesArray() throws {
        struct Item: Decodable, Equatable { let name: String }
        let json = #"[{"name": "a"}, {"name": "b"}]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LFMList<Item>.self, from: json)
        #expect(decoded.items == [Item(name: "a"), Item(name: "b")])
    }

    @Test("LFMList tolerates a single item collapsed to a bare object")
    func decodesSingleObject() throws {
        struct Item: Decodable, Equatable { let name: String }
        let json = #"{"name": "a"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LFMList<Item>.self, from: json)
        #expect(decoded.items == [Item(name: "a")])
    }

    @Test("LFMAlbum decodes a real album.getInfo tracklist payload")
    func decodesAlbumTracklist() throws {
        let json = """
        {
            "name": "Knives Out - EP",
            "artist": "Radiohead",
            "mbid": null,
            "url": "https://www.last.fm/music/Radiohead/Knives+Out+-+EP",
            "listeners": "163071",
            "playcount": "1791497",
            "tracks": {
                "track": [
                    {"name": "Knives Out", "@attr": {"rank": 1}},
                    {"name": "Cuttooth", "@attr": {"rank": 2}}
                ]
            }
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LFMAlbum.self, from: json)
        #expect(decoded.tracks?.track?.map(\.name) == ["Knives Out", "Cuttooth"])
        #expect(decoded.tracks?.track?.first?.attr?.rank?.value == 1)
    }

    @Test("LFMAlbum tolerates a single-track album's tracklist collapsing to a bare object")
    func decodesSingleTrackTracklist() throws {
        let json = """
        {
            "name": "Knives Out",
            "artist": "Radiohead",
            "mbid": null,
            "url": "https://www.last.fm/music/Radiohead/Knives+Out",
            "listeners": "1",
            "playcount": "1",
            "tracks": {
                "track": {"name": "Knives Out", "@attr": {"rank": 1}}
            }
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LFMAlbum.self, from: json)
        #expect(decoded.tracks?.track?.map(\.name) == ["Knives Out"])
    }
}
