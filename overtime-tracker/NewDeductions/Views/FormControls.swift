import SwiftUI

struct YesNoPicker: View {
    let title: String
    let detail: String
    @Binding var selection: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                choice("Yes", value: true)
                choice("No", value: false)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func choice(_ label: String, value: Bool) -> some View {
        Button {
            selection = value
        } label: {
            Text(label)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(selection == value ? Color.accentColor : Color.secondary)
        .accessibilityLabel("\(title), \(label)")
        .accessibilityAddTraits(selection == value ? .isSelected : AccessibilityTraits())
    }
}

/// A money figure with the word "estimate" in the label. The amount uses a scaling font.
struct EstimateLine: View {
    let title: String
    let amount: Decimal
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(AppFormatting.currency(amount))
                .font(.title3)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
