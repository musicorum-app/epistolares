import Foundation
@testable import Resources

actor MockLastFMClient: LastFMClientProtocol {
    private var artists: [String: LFMArtist] = [:]
    private var albums: [String: LFMAlbum] = [:]
    private var tracks: [String: LFMTrack] = [:]
    private var validUsernames: Set<String> = []
    private var topArtistsCharts: [String: LFMTopArtists] = [:]
    private var topAlbumsCharts: [String: LFMTopAlbums] = [:]
    private var topTracksCharts: [String: LFMTopTracks] = [:]
    private var recentTracksLists: [String: LFMRecentTracks] = [:]

    private(set) var calls: [String] = []

    func setArtist(_ artist: LFMArtist, forName name: String) {
        artists[name.lowercased()] = artist
    }

    func setAlbum(_ album: LFMAlbum, forArtist artist: String, name: String) {
        albums["\(artist.lowercased())|\(name.lowercased())"] = album
    }

    func setTrack(_ track: LFMTrack, forArtist artist: String, name: String) {
        tracks["\(artist.lowercased())|\(name.lowercased())"] = track
    }

    func setValidUsername(_ username: String) {
        validUsernames.insert(username.lowercased())
    }

    func setTopArtists(_ chart: LFMTopArtists, username: String, period: String, limit: Int, page: Int) {
        topArtistsCharts["\(username.lowercased())|\(period)|\(limit)|\(page)"] = chart
    }

    func setTopAlbums(_ chart: LFMTopAlbums, username: String, period: String, limit: Int, page: Int) {
        topAlbumsCharts["\(username.lowercased())|\(period)|\(limit)|\(page)"] = chart
    }

    func setTopTracks(_ chart: LFMTopTracks, username: String, period: String, limit: Int, page: Int) {
        topTracksCharts["\(username.lowercased())|\(period)|\(limit)|\(page)"] = chart
    }

    func setRecentTracks(_ list: LFMRecentTracks, username: String, limit: Int, page: Int) {
        recentTracksLists["\(username.lowercased())|\(limit)|\(page)"] = list
    }

    func artistInfo(name: String, username: String?) async throws -> LFMArtist {
        calls.append("artistInfo(\(name), username: \(username ?? "nil"))")
        guard let artist = artists[name.lowercased()] else { throw LastFMError.notFound }
        return artist
    }

    func albumInfo(name: String, artist: String, username: String?) async throws -> LFMAlbum {
        calls.append("albumInfo(\(name), artist: \(artist), username: \(username ?? "nil"))")
        guard let album = albums["\(artist.lowercased())|\(name.lowercased())"] else { throw LastFMError.notFound }
        return album
    }

    func trackInfo(name: String, artist: String, username: String?) async throws -> LFMTrack {
        calls.append("trackInfo(\(name), artist: \(artist), username: \(username ?? "nil"))")
        guard let track = tracks["\(artist.lowercased())|\(name.lowercased())"] else { throw LastFMError.notFound }
        return track
    }

    func validateUsername(_ username: String) async throws {
        calls.append("validateUsername(\(username))")
        guard validUsernames.contains(username.lowercased()) else { throw LastFMError.notFound }
    }

    func topArtists(username: String, period: String, limit: Int, page: Int) async throws -> LFMTopArtists {
        calls.append("topArtists(\(username), period: \(period), limit: \(limit), page: \(page))")
        guard let chart = topArtistsCharts["\(username.lowercased())|\(period)|\(limit)|\(page)"] else { throw LastFMError.notFound }
        return chart
    }

    func topAlbums(username: String, period: String, limit: Int, page: Int) async throws -> LFMTopAlbums {
        calls.append("topAlbums(\(username), period: \(period), limit: \(limit), page: \(page))")
        guard let chart = topAlbumsCharts["\(username.lowercased())|\(period)|\(limit)|\(page)"] else { throw LastFMError.notFound }
        return chart
    }

    func topTracks(username: String, period: String, limit: Int, page: Int) async throws -> LFMTopTracks {
        calls.append("topTracks(\(username), period: \(period), limit: \(limit), page: \(page))")
        guard let chart = topTracksCharts["\(username.lowercased())|\(period)|\(limit)|\(page)"] else { throw LastFMError.notFound }
        return chart
    }

    func recentTracks(username: String, limit: Int, page: Int) async throws -> LFMRecentTracks {
        calls.append("recentTracks(\(username), limit: \(limit), page: \(page))")
        guard let list = recentTracksLists["\(username.lowercased())|\(limit)|\(page)"] else { throw LastFMError.notFound }
        return list
    }
}

/// Builds fixtures via `JSONSerialization` (not string interpolation), so arbitrary text
/// (quotes, HTML, etc., like real Last.fm bios) can't corrupt the JSON.
private func decode<T: Decodable>(_ type: T.Type, object: [String: Any]) -> T {
    let data = try! JSONSerialization.data(withJSONObject: object)
    return try! JSONDecoder().decode(T.self, from: data)
}

private func imagesJSON(_ images: [LFMImage]?) -> [[String: Any]] {
    (images ?? []).map { ["#text": $0.text, "size": $0.size] }
}

private func tagsJSON(_ tags: [LFMTag]?) -> [[String: Any]] {
    (tags ?? []).map { ["name": $0.name, "url": $0.url] }
}

extension LFMArtist {
    static func fixture(
        name: String,
        mbid: String? = nil,
        url: String = "https://www.last.fm/music/Artist",
        image: [LFMImage]? = [LFMImage(text: "https://lastfm.freetls.fastly.net/i/u/300x300/abc123.jpg", size: "extralarge")],
        listeners: Int? = 1000,
        playcount: Int? = 10000,
        userplaycount: Int? = nil,
        similar: [LFMArtist.SimilarArtist]? = nil,
        tags: [LFMTag]? = nil,
        bioSummary: String? = nil,
        bioContent: String? = nil
    ) -> LFMArtist {
        decode(LFMArtist.self, object: [
            "name": name,
            "mbid": mbid as Any? ?? NSNull(),
            "url": url,
            "image": imagesJSON(image),
            "stats": [
                "listeners": listeners.map { "\($0)" } as Any? ?? NSNull(),
                "playcount": playcount.map { "\($0)" } as Any? ?? NSNull(),
                "userplaycount": userplaycount.map { "\($0)" } as Any? ?? NSNull(),
            ],
            "similar": ["artist": (similar ?? []).map { ["name": $0.name, "url": $0.url, "image": imagesJSON($0.image)] }],
            "tags": ["tag": tagsJSON(tags)],
            "bio": [
                "summary": bioSummary as Any? ?? NSNull(),
                "content": bioContent as Any? ?? NSNull(),
            ],
        ])
    }
}

extension LFMAlbum {
    static func fixture(
        name: String,
        artist: String,
        mbid: String? = nil,
        url: String = "https://www.last.fm/music/Artist/Album",
        image: [LFMImage]? = [LFMImage(text: "https://lastfm.freetls.fastly.net/i/u/300x300/def456.jpg", size: "extralarge")],
        listeners: Int? = 500,
        playcount: Int? = 5000,
        userplaycount: Int? = nil,
        tags: [LFMTag]? = nil,
        tracks: [(name: String, rank: Int)] = []
    ) -> LFMAlbum {
        decode(LFMAlbum.self, object: [
            "name": name,
            "artist": artist,
            "mbid": mbid as Any? ?? NSNull(),
            "url": url,
            "image": imagesJSON(image),
            "listeners": listeners.map { "\($0)" } as Any? ?? NSNull(),
            "playcount": playcount.map { "\($0)" } as Any? ?? NSNull(),
            "userplaycount": userplaycount.map { "\($0)" } as Any? ?? NSNull(),
            "tags": ["tag": tagsJSON(tags)],
            "tracks": ["track": tracks.map { ["name": $0.name, "@attr": ["rank": $0.rank]] }],
        ])
    }
}

extension LFMTrack {
    static func fixture(
        name: String,
        mbid: String? = nil,
        url: String = "https://www.last.fm/music/Artist/_/Track",
        duration: Int? = 200,
        listeners: Int? = 300,
        playcount: Int? = 3000,
        userplaycount: Int? = nil,
        userloved: Bool? = nil,
        albumTitle: String? = nil,
        albumArtist: String? = nil,
        tags: [LFMTag]? = nil
    ) -> LFMTrack {
        let album: Any
        if let albumTitle {
            album = ["artist": albumArtist as Any? ?? NSNull(), "title": albumTitle, "mbid": NSNull(), "url": NSNull(), "image": [[String: Any]]()]
        } else {
            album = NSNull()
        }

        return decode(LFMTrack.self, object: [
            "name": name,
            "mbid": mbid as Any? ?? NSNull(),
            "url": url,
            "duration": duration.map { "\($0)" } as Any? ?? NSNull(),
            "listeners": listeners.map { "\($0)" } as Any? ?? NSNull(),
            "playcount": playcount.map { "\($0)" } as Any? ?? NSNull(),
            "userplaycount": userplaycount.map { "\($0)" } as Any? ?? NSNull(),
            "userloved": userloved.map { $0 ? "1" : "0" } as Any? ?? NSNull(),
            "artist": ["name": "Artist", "mbid": NSNull(), "url": NSNull()],
            "album": album,
            "toptags": ["tag": tagsJSON(tags)],
        ])
    }
}

private func chartAttrJSON(page: Int, totalPages: Int, total: Int) -> [String: Any] {
    ["page": "\(page)", "totalPages": "\(totalPages)", "total": "\(total)"]
}

extension LFMTopArtists {
    static func fixture(
        entries: [(name: String, rank: Int, playcount: Int)],
        page: Int = 1,
        totalPages: Int = 1,
        total: Int? = nil
    ) -> LFMTopArtists {
        decode(LFMTopArtists.self, object: [
            "artist": entries.map { ["name": $0.name, "url": "https://www.last.fm/music/\($0.name)", "playcount": "\($0.playcount)", "@attr": ["rank": "\($0.rank)"]] },
            "@attr": chartAttrJSON(page: page, totalPages: totalPages, total: total ?? entries.count),
        ])
    }
}

extension LFMTopAlbums {
    static func fixture(
        entries: [(name: String, artist: String, rank: Int, playcount: Int)],
        page: Int = 1,
        totalPages: Int = 1,
        total: Int? = nil
    ) -> LFMTopAlbums {
        decode(LFMTopAlbums.self, object: [
            "album": entries.map { ["name": $0.name, "url": "https://www.last.fm/music/\($0.artist)/\($0.name)", "playcount": "\($0.playcount)", "artist": ["name": $0.artist, "url": "https://www.last.fm/music/\($0.artist)"], "@attr": ["rank": "\($0.rank)"]] },
            "@attr": chartAttrJSON(page: page, totalPages: totalPages, total: total ?? entries.count),
        ])
    }
}

extension LFMTopTracks {
    static func fixture(
        entries: [(name: String, artist: String, rank: Int, playcount: Int)],
        page: Int = 1,
        totalPages: Int = 1,
        total: Int? = nil
    ) -> LFMTopTracks {
        decode(LFMTopTracks.self, object: [
            "track": entries.map { ["name": $0.name, "url": "https://www.last.fm/music/\($0.artist)/_/\($0.name)", "playcount": "\($0.playcount)", "artist": ["name": $0.artist, "url": "https://www.last.fm/music/\($0.artist)"], "@attr": ["rank": "\($0.rank)"]] },
            "@attr": chartAttrJSON(page: page, totalPages: totalPages, total: total ?? entries.count),
        ])
    }
}

extension LFMRecentTracks {
    static func fixture(
        entries: [(name: String, artist: String, album: String?, uts: Int?, nowPlaying: Bool)],
        page: Int = 1,
        totalPages: Int = 1,
        total: Int? = nil
    ) -> LFMRecentTracks {
        decode(LFMRecentTracks.self, object: [
            "track": entries.map { entry -> [String: Any] in
                var json: [String: Any] = [
                    "name": entry.name,
                    "url": "https://www.last.fm/music/\(entry.artist)/_/\(entry.name)",
                    "artist": ["mbid": "", "#text": entry.artist],
                    "album": ["mbid": "", "#text": entry.album ?? ""],
                ]
                if let uts = entry.uts {
                    json["date"] = ["uts": "\(uts)", "#text": ""]
                }
                if entry.nowPlaying {
                    json["@attr"] = ["nowplaying": "true"]
                }
                return json
            },
            "@attr": chartAttrJSON(page: page, totalPages: totalPages, total: total ?? entries.count),
        ])
    }
}
