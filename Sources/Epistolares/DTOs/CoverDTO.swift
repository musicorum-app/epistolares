import Vapor

struct CoverDTO: Content, Sendable {
    var defaultURL: String
    var template: String
}

extension Cover {
    /// `nil` when Last.fm never had an image for this entity (`externalID` empty).
    func toCoverDTO() -> CoverDTO? {
        guard let defaultURL = toCoverURL(dimensions: .small) else { return nil }
        switch source {
        case .lastfm:
            return CoverDTO(
                defaultURL: defaultURL.absoluteString,
                template: "https://lastfm.freetls.fastly.net/i/u/{w}x{h}/\(externalID).jpg"
            )
        }
    }

    static func toCoverDTO(externalID: String?) -> CoverDTO? {
        guard let externalID, !externalID.isEmpty else { return nil }
        return CoverDTO(
            defaultURL: "https://lastfm.freetls.fastly.net/i/u/300x300/\(externalID).jpg",
            template: "https://lastfm.freetls.fastly.net/i/u/{w}x{h}/\(externalID).jpg"
        )
    }
}
