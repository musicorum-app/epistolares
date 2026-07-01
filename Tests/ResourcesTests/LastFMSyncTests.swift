@testable import Resources
import Testing
import Foundation

@Suite("LastFMSync helpers")
struct LastFMSyncTests {
    @Test("stripReadMoreLink cuts off at the Last.fm read-more link")
    func stripsReadMoreLink() {
        let bio = "Some real bio text. <a href=\"https://www.last.fm/music/Kelela\">Read more on Last.fm</a>. User-contributed text is available under the Creative Commons By-SA License; additional terms may apply."
        #expect(LastFMSync.stripReadMoreLink(bio) == "Some real bio text.")
    }

    @Test("stripReadMoreLink leaves text with no read-more link untouched")
    func leavesPlainTextUntouched() {
        #expect(LastFMSync.stripReadMoreLink("Just a plain bio.") == "Just a plain bio.")
    }

    @Test("stripReadMoreLink passes through nil")
    func passesThroughNil() {
        #expect(LastFMSync.stripReadMoreLink(nil) == nil)
    }

    @Test("stripReadMoreLink returns nil for text that is only the link")
    func emptyAfterStrippingBecomesNil() {
        let bio = "<a href=\"https://www.last.fm/music/Kelela\">Read more on Last.fm</a>."
        #expect(LastFMSync.stripReadMoreLink(bio) == nil)
    }

    @Test("coverExternalID pulls the hash out of a Last.fm image URL")
    func extractsCoverExternalID() {
        let images = [
            LFMImage(text: "https://lastfm.freetls.fastly.net/i/u/300x300/d99ce9cb021385129b01be524dce84e3.jpg", size: "extralarge"),
        ]
        #expect(LastFMSync.coverExternalID(from: images) == "d99ce9cb021385129b01be524dce84e3")
    }

    @Test("coverExternalID skips blank entries and uses the last non-empty image")
    func skipsBlankImageEntries() {
        let images = [
            LFMImage(text: "https://lastfm.freetls.fastly.net/i/u/34s/abc123.png", size: "small"),
            LFMImage(text: "", size: "mega"),
        ]
        #expect(LastFMSync.coverExternalID(from: images) == "abc123")
    }

    @Test("coverExternalID returns nil with no images")
    func returnsNilWithNoImages() {
        #expect(LastFMSync.coverExternalID(from: nil) == nil)
        #expect(LastFMSync.coverExternalID(from: []) == nil)
    }

    @Test("isStale treats a missing date as stale")
    func nilDateIsStale() {
        #expect(LastFMSync.isStale(nil, ttl: 60) == true)
    }

    @Test("isStale is false within the TTL window")
    func recentDateIsNotStale() {
        #expect(LastFMSync.isStale(Date(), ttl: 60) == false)
    }

    @Test("isStale is true past the TTL window")
    func oldDateIsStale() {
        let old = Date().addingTimeInterval(-120)
        #expect(LastFMSync.isStale(old, ttl: 60) == true)
    }
}
