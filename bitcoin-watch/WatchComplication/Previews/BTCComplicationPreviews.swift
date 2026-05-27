import SwiftUI
import WidgetKit

private let sampleEntry = WatchBTCEntry(
    date: Date(),
    price: BitcoinPrice(usd: 98_245, timestamp: Date(timeIntervalSinceNow: -185)),
    isFetching: false
)

#Preview("Circular", as: .accessoryCircular) {
    BTCWatchComplication()
} timeline: {
    sampleEntry
}

#Preview("Rectangular", as: .accessoryRectangular) {
    BTCWatchComplication()
} timeline: {
    sampleEntry
}

#Preview("Inline", as: .accessoryInline) {
    BTCWatchComplication()
} timeline: {
    sampleEntry
}

#Preview("Corner", as: .accessoryCorner) {
    BTCWatchComplication()
} timeline: {
    sampleEntry
}
