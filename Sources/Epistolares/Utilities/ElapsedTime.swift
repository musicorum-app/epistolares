import Foundation

extension ContinuousClock.Instant {
    var elapsedMs: String {
        let duration = self.duration(to: .now)
        let ms = Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1_000_000_000_000_000
        return String(format: "%.1f", ms)
    }
}
