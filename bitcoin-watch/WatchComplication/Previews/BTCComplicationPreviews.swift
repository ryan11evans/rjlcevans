import SwiftUI
import WidgetKit

private func previewEntry(age: TimeInterval, price: Double = 98_245) -> WatchBTCEntry {
    // Distinct, increasing dates so the preview timeline can show each age.
    let shownAt = Date(timeIntervalSince1970: 1_762_214_400).addingTimeInterval(age)
    return WatchBTCEntry(
        date: shownAt,
        price: BitcoinPrice(usd: price, timestamp: shownAt.addingTimeInterval(-age)),
        isFetching: false
    )
}

// Two-digit minutes are the case that used to clip ("9m" fit, "10m" did not).
private let sampleEntry = previewEntry(age: 10 * 60)

#Preview("Circular", as: .accessoryCircular) {
    BTCWatchComplicationBundle()
} timeline: {
    previewEntry(age: 9 * 60)
    previewEntry(age: 10 * 60)
    previewEntry(age: 59 * 60)
    previewEntry(age: 10 * 3600)
    previewEntry(age: 10 * 86_400)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    BTCWatchComplicationBundle()
} timeline: {
    sampleEntry
}

#Preview("Inline", as: .accessoryInline) {
    BTCWatchComplicationBundle()
} timeline: {
    sampleEntry
}

#Preview("Corner", as: .accessoryCorner) {
    BTCWatchComplicationBundle()
} timeline: {
    sampleEntry
}
