import SwiftUI

// A month-grid event chip: wraps to two lines instead of the stock Calendar's
// single-line truncation, so the title stays readable without tapping in.
struct EventChip: View {
    let event: CalendarEvent
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.tag.color)
                .frame(width: 3)
            Text(chipText)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .padding(.trailing, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(event.tag.color.opacity(0.22))
        )
    }

    private var chipText: String {
        event.isAllDay ? event.title : "\(event.title)"
    }
}

struct MoreEventsPill: View {
    let count: Int
    var body: some View {
        Text("+\(count) more")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
