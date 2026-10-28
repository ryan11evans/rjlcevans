import SwiftUI

struct YesNoPicker: View {
    let title: String
    let detail: String
    @Binding var selection: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.rounded(.body, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(Theme.rounded(.footnote))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                choice("Yes", value: true)
                choice("No", value: false)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func choice(_ label: String, value: Bool) -> some View {
        let selected = selection == value
        return Button {
            selection = value
        } label: {
            Text(label)
                .font(Theme.rounded(.headline, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Theme.emerald : Theme.backgroundElevated)
                )
                .foregroundStyle(selected ? Color.white : Theme.ink)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(title), \(label)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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
                .font(Theme.rounded(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ThemeMoney(amount: amount, style: .title3)
            if let detail {
                Text(detail)
                    .font(Theme.rounded(.caption))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
