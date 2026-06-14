import SwiftUI
import WidgetKit

private let sampleEntry = WatchBTCEntry(
    date: Date(),
    price: BitcoinPrice(usd: 98_245, timestamp: Date(timeIntervalSinceNow: -185)),
    isFetching: false
)

#Preview("Circular", as: .accessoryCircular) {
    BTCWatchComplicationBundle()
} timeline: {
    sampleEntry
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
