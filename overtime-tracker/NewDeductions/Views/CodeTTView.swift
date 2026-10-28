import OvertimeCore
import SwiftData
import SwiftUI

struct CodeTTView: View {
    @Environment(\.modelContext) private var modelContext
    let employer: Employer
    let profile: TaxProfile
    let weeks: [Week]

    @State private var text = ""
    @State private var loaded = false
    @State private var message: String?
    @FocusState private var amountFocused: Bool

    private var computed: Decimal {
        OvertimeCalculator.ytdQualifiedPremium(weeks.map(\.workWeek))
    }

    var body: some View {
        Form {
            Section {
                TextField("W-2 Box 12 code TT", text: $text)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                Button("Save code TT") { save() }
            } header: {
                Text(String(profile.taxYear))
            } footer: {
                Text("The amount printed on the W-2 for this tax year. Many 2025 W-2s do not include code TT. Leave the field blank and save to clear it.")
            }

            if let reported = AppFormatting.parseDecimal(text) {
                let difference = Schedule1ACalculator.compareCodeTT(reported: reported, computedPremium: computed)
                Section {
                    EstimateLine(title: "Code TT from the W-2", amount: reported)
                    EstimateLine(title: "Qualified premium from this log (estimate)", amount: computed)
                    EstimateLine(
                        title: "Difference, code TT minus the log (estimate)",
                        amount: difference.reportedMinusComputed
                    )
                    Text(CodeTTCopy.explanation(difference: difference))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section {
                    EstimateLine(title: "Qualified premium from this log (estimate)", amount: computed)
                    Text("Enter code TT to compare it with the log.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Text(AppCopy.estimateFootnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Code TT")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let stored = employer.codeTT[profile.taxYear] {
                text = AppFormatting.editableDecimal(stored)
            }
        }
    }

    private func save() {
        amountFocused = false
        message = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            employer.setCodeTT(nil, for: profile.taxYear)
            try? modelContext.save()
            return
        }
        guard let amount = AppFormatting.parseDecimal(trimmed), amount >= 0 else {
            message = "Enter the code TT amount as a dollar figure."
            return
        }
        employer.setCodeTT(amount, for: profile.taxYear)
        try? modelContext.save()
    }
}
