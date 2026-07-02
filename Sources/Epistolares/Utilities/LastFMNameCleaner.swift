import Foundation

enum LastFMNameCleaner {
    private static let albumPatterns = [
        #"\s*-\s*(EP|Single)\s*$"#,
    ]

    private static let trackPatterns = [
        #"\s*\(feat\.[^)]*\)\s*$"#,
        #"\s*-\s*.*\bVersion\s*$"#,
        #"\s*-\s*.*\bRemaster(ed)?\s*$"#,
        #"\s*-\s*.*\bRemaster(ed)?\s+Version\s*$"#,
        #"\s*-\s*Remaster(ed)?\s+.*$"#,
    ]

    static func cleanAlbumName(_ name: String) -> String {
        strip(name, patterns: albumPatterns)
    }

    static func cleanTrackName(_ name: String) -> String {
        strip(name, patterns: trackPatterns)
    }

    private static func strip(_ name: String, patterns: [String]) -> String {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(name.startIndex..., in: name)
            if let match = regex.firstMatch(in: name, range: range) {
                let cleaned = (name as NSString).replacingCharacters(in: match.range, with: "")
                return cleaned.trimmingCharacters(in: .whitespaces)
            }
        }
        return name
    }
}
