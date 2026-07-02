import Dispatch
import Foundation

extension DispatchTime {
    var elapsedMs: String {
        String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - uptimeNanoseconds) / 1_000_000)
    }
}
