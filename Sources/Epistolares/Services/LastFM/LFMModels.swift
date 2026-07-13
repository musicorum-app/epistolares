import Foundation

enum LastFMError: Error {
    case notFound
    case apiError(code: Int, message: String)
    case invalidResponse
    case unauthorized
}

struct LFMErrorResponse: Decodable {
    let error: Int
    let message: String
}

/// Last.fm can encode numeric fields as JSON strings and sometimes omits them entirely.
struct LFMIntString: Decodable {
    let value: Int?

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = Int(stringValue)
        } else {
            value = nil
        }
    }
}

struct LFMImage: Decodable {
    let text: String
    let size: String

    enum CodingKeys: String, CodingKey {
        case text = "#text"
        case size
    }
}

/// A list with exactly one item collapses to a bare object instead of a one-element array
/// (this hits tags, similar artists, album tracklists, ...).
struct LFMList<Element: Decodable>: Decodable {
    let items: [Element]

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([Element].self) {
            items = array
        } else if let single = try? container.decode(Element.self) {
            items = [single]
        } else {
            items = []
        }
    }
}

extension KeyedDecodingContainer {
    /// Decodes a keyed field through `LFMList`, unwrapping straight to `[Element]?`.
    func decodeLFMList<Element: Decodable>(forKey key: Key) throws -> [Element]? {
        try decodeIfPresent(LFMList<Element>.self, forKey: key)?.items
    }
}

struct LFMTag: Decodable {
    let name: String
    let url: String
}

struct LFMTagsWrapper: Decodable {
    let tag: [LFMTag]?

    /// Last.fm sends `"tags": ""` (an empty string) instead of `{"tag": []}` when there are none
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let keyed = try? container.decode(KeyedTags.self) {
            tag = keyed.tag?.items
        } else {
            tag = nil
        }
    }

    private struct KeyedTags: Decodable {
        let tag: LFMList<LFMTag>?
    }
}

struct LFMWiki: Decodable {
    let published: String?
    let summary: String?
    let content: String?
}

// MARK: - user.getInfo

struct LFMUserInfoResponse: Decodable {
    let user: LFMUserBasic
}

struct LFMUserBasic: Decodable {
    let name: String
}

// MARK: - artist.getInfo

struct LFMArtistResponse: Decodable {
    let artist: LFMArtist
}

struct LFMArtist: Decodable {
    struct Stats: Decodable {
        let listeners: LFMIntString?
        let playcount: LFMIntString?
        let userplaycount: LFMIntString?
    }

    struct SimilarArtist: Decodable {
        let name: String
        let url: String
        let image: [LFMImage]?
    }

    struct Similar: Decodable {
        let artist: [SimilarArtist]?

        init(from decoder: any Decoder) throws {
            artist = try decoder.container(keyedBy: CodingKeys.self).decodeLFMList(forKey: .artist)
        }

        enum CodingKeys: String, CodingKey {
            case artist
        }
    }

    let name: String
    let mbid: String?
    let url: String
    let image: [LFMImage]?
    let stats: Stats?
    let similar: Similar?
    let tags: LFMTagsWrapper?
    let bio: LFMWiki?
}

// MARK: - album.getInfo

struct LFMAlbumResponse: Decodable {
    let album: LFMAlbum
}

struct LFMAlbum: Decodable {
    struct AlbumTrackAttr: Decodable {
        let rank: LFMIntString?
    }

    struct AlbumTrack: Decodable {
        let name: String
        let attr: AlbumTrackAttr?

        enum CodingKeys: String, CodingKey {
            case name
            case attr = "@attr"
        }
    }

    struct Tracks: Decodable {
        let track: [AlbumTrack]?

        init(from decoder: any Decoder) throws {
            track = try decoder.container(keyedBy: CodingKeys.self).decodeLFMList(forKey: .track)
        }

        enum CodingKeys: String, CodingKey {
            case track
        }
    }

    let name: String
    let artist: String
    let mbid: String?
    let url: String
    let image: [LFMImage]?
    let listeners: LFMIntString?
    let playcount: LFMIntString?
    let userplaycount: LFMIntString?
    let tags: LFMTagsWrapper?
    let tracks: Tracks?
    let wiki: LFMWiki?
}

// MARK: - track.getInfo

struct LFMTrackResponse: Decodable {
    let track: LFMTrack
}

struct LFMTrack: Decodable {
    struct Artist: Decodable {
        let name: String
        let mbid: String?
        let url: String?
    }

    struct Album: Decodable {
        let artist: String?
        let title: String
        let mbid: String?
        let url: String?
        let image: [LFMImage]?
    }

    let name: String
    let mbid: String?
    let url: String
    let duration: LFMIntString?
    let listeners: LFMIntString?
    let playcount: LFMIntString?
    let userplaycount: LFMIntString?
    let userloved: LFMIntString?
    let artist: Artist?
    let album: Album?
    let toptags: LFMTagsWrapper?
}

// MARK: - user.gettop{artists,albums,tracks}

struct LFMChartAttr: Decodable {
    let page: LFMIntString
    let totalPages: LFMIntString
    let total: LFMIntString
}

struct LFMChartArtistRef: Decodable {
    let name: String
    let mbid: String?
    let url: String
}

struct LFMChartRankAttr: Decodable {
    let rank: LFMIntString?
}

struct LFMTopArtistsResponse: Decodable {
    let topartists: LFMTopArtists
}

struct LFMTopArtists: Decodable {
    struct Entry: Decodable {
        let name: String
        let mbid: String?
        let url: String
        let image: [LFMImage]?
        let playcount: LFMIntString?
        let attr: LFMChartRankAttr?

        enum CodingKeys: String, CodingKey {
            case name, mbid, url, image, playcount
            case attr = "@attr"
        }
    }

    let artist: [Entry]?
    let attr: LFMChartAttr

    enum CodingKeys: String, CodingKey {
        case artist
        case attr = "@attr"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artist = try container.decodeLFMList(forKey: .artist)
        attr = try container.decode(LFMChartAttr.self, forKey: .attr)
    }
}

struct LFMTopAlbumsResponse: Decodable {
    let topalbums: LFMTopAlbums
}

struct LFMTopAlbums: Decodable {
    struct Entry: Decodable {
        let name: String
        let mbid: String?
        let url: String
        let image: [LFMImage]?
        let playcount: LFMIntString?
        let artist: LFMChartArtistRef
        let attr: LFMChartRankAttr?

        enum CodingKeys: String, CodingKey {
            case name, mbid, url, image, playcount, artist
            case attr = "@attr"
        }
    }

    let album: [Entry]?
    let attr: LFMChartAttr

    enum CodingKeys: String, CodingKey {
        case album
        case attr = "@attr"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        album = try container.decodeLFMList(forKey: .album)
        attr = try container.decode(LFMChartAttr.self, forKey: .attr)
    }
}

struct LFMTopTracksResponse: Decodable {
    let toptracks: LFMTopTracks
}

struct LFMTopTracks: Decodable {
    struct Entry: Decodable {
        let name: String
        let mbid: String?
        let url: String
        let image: [LFMImage]?
        let duration: LFMIntString?
        let playcount: LFMIntString?
        let artist: LFMChartArtistRef
        let attr: LFMChartRankAttr?

        enum CodingKeys: String, CodingKey {
            case name, mbid, url, image, duration, playcount, artist
            case attr = "@attr"
        }
    }

    let track: [Entry]?
    let attr: LFMChartAttr

    enum CodingKeys: String, CodingKey {
        case track
        case attr = "@attr"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        track = try container.decodeLFMList(forKey: .track)
        attr = try container.decode(LFMChartAttr.self, forKey: .attr)
    }
}

// MARK: - user.getRecentTracks

struct LFMRecentTracksResponse: Decodable {
    let recenttracks: LFMRecentTracks
}

struct LFMRecentTracks: Decodable {
    struct TextRef: Decodable {
        let mbid: String?
        let text: String

        enum CodingKeys: String, CodingKey {
            case mbid
            case text = "#text"
        }
    }

    struct DateRef: Decodable {
        let uts: LFMIntString
    }

    struct Attr: Decodable {
        let nowplaying: String?
    }

    struct Entry: Decodable {
        let name: String
        let url: String
        let artist: TextRef
        let album: TextRef?
        let date: DateRef?
        let attr: Attr?
        let image: [LFMImage]?

        enum CodingKeys: String, CodingKey {
            case name, url, artist, album, date, image
            case attr = "@attr"
        }
    }

    let track: [Entry]?
    let attr: LFMChartAttr

    enum CodingKeys: String, CodingKey {
        case track
        case attr = "@attr"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        track = try container.decodeLFMList(forKey: .track)
        attr = try container.decode(LFMChartAttr.self, forKey: .attr)
    }
}
