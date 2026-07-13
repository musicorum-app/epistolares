@testable import Epistolares
import Testing

@Suite("LastFMNameCleaner")
struct LastFMNameCleanerTests {
    @Test("strips feat. from track names", arguments: [
        ("Are You Bored Yet? (feat. Clairo)", "Are You Bored Yet?"),
        ("Song Title (feat. Someone)", "Song Title"),
    ])
    func stripsFeat(input: String, expected: String) {
        #expect(LastFMNameCleaner.cleanTrackName(input) == expected)
    }

    @Test("strips remaster suffixes from track names", arguments: [
        ("Song - 2015 Remaster", "Song"),
        ("Song - 2011 Remastered", "Song"),
        ("Song - Remastered Version", "Song"),
    ])
    func stripsRemaster(input: String, expected: String) {
        #expect(LastFMNameCleaner.cleanTrackName(input) == expected)
    }

    @Test("leaves plain track names untouched")
    func leavesPlainTrackUntouched() {
        #expect(LastFMNameCleaner.cleanTrackName("Worrywort") == "Worrywort")
    }

    @Test("strips EP/Single suffixes from album names", arguments: [
        ("Album - EP", "Album"),
        ("Album - Single", "Album"),
    ])
    func stripsAlbumSuffix(input: String, expected: String) {
        #expect(LastFMNameCleaner.cleanAlbumName(input) == expected)
    }

    @Test("leaves an album name with no EP/Single suffix untouched")
    func leavesPlainAlbumUntouched() {
        // Regression guard: "Knives Out" and "Knives Out - EP" are distinct Last.fm releases,
        // so the cleaner must only ever strip an actual trailing " - EP"/" - Single", never guess.
        #expect(LastFMNameCleaner.cleanAlbumName("Knives Out") == "Knives Out")
    }
}
