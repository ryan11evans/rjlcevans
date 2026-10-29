import OvertimeCore
import SwiftData
import SwiftUI

struct CodeTTView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premium: PremiumStore

    let employer: Employer
    let profile: TaxProfile
    let weeks: [Week]

    @State private var text = ""
    @State private var loaded = false
    @State private var markedAbsent = false
    @State private var compared = false
    @State private var message: String?
    @FocusState private var amountFocused: Bool

    private var computed: Decimal {
        OvertimeCalculator.ytdQualifiedPremium(weeks.map(\.workWeek))
    }

    private var comparison: CodeTTComparison? {
        guard compared else { return nil }
        if markedAbsent { return .notOnW2 }
        guard let reported = AppFormatting.parseDecimal(text) else { return nil }
        return Schedule1ACalculator.comparison(reported: reported, computedPremium: computed)
    }

    var body: some View {
        Group {
            if premium.isPremium {
                flow
            } else {
                List {
                    Section {
                        PremiumLockedSection(message: "The W-2 Code TT check is part of Pro.")
                    }
                }
            }
        }
        .navigationTitle("Check my W-2")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var flow: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SoftCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Box 12, code TT")
                            .font(.title2.weight(.bold))
                        Text("Code TT is the qualified overtime premium, the extra half of time-and-a-half, not the full overtime pay. Compare it with the premium this log computed. \(CodeTTCopy.transitionYear)")
                        Text("Tax year \(String(profile.taxYear)). Estimate only, not tax advice.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                SoftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("W-2 amount")
                            .font(.headline)
                        TextField("Box 12 code TT", text: $text)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .font(.title2.weight(.semibold))
                        Button("Compare") { compareAmount() }
                            .buttonStyle(.borderedProminent)
                        Button("Not on my W-2") { markAbsent() }
                            .buttonStyle(.bordered)
                        if let message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }

                if let comparison {
                    resultCard(comparison)
                    shareCard(comparison)
                } else {
                    SoftCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Qualified premium from this log (estimate)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(AppFormatting.currency(computed))
                                .font(.title3.weight(.semibold))
                        }
                    }
                }

                Text(AppCopy.estimateFootnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
        .onAppear(perform: load)
    }

    private func resultCard(_ comparison: CodeTTComparison) -> some View {
        let dollars = CodeTTCopy.dollars(comparison)
        return VStack(alignment: .leading, spacing: 8) {
            Text(CodeTTCopy.headline(comparison))
                .font(.headline)
                .foregroundStyle(Theme.gold)
            if let dollars {
                Text(AppFormatting.currency(dollars))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("Dollar difference (estimate)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            } else if comparison == .match {
                Text(AppFormatting.currency(computed))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Same amount (estimate)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Text(CodeTTCopy.explanation(comparison: comparison, taxYear: profile.taxYear))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.heroGradient))
        .accessibilityElement(children: .combine)
    }

    private func shareCard(_ comparison: CodeTTComparison) -> some View {
        let reported = markedAbsent ? nil : AppFormatting.parseDecimal(text)
        let note = CodeTTCopy.payrollNote(
            taxYear: profile.taxYear,
            computed: computed,
            reported: reported,
            comparison: comparison
        )
        return SoftCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ask payroll to verify")
                    .font(.headline)
                Text("A short note you can send. It asks them to check code TT. It is polite, and it says the figure is an estimate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ShareLink(item: note) {
                    Label("Share note to payroll", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let stored = employer.codeTT[profile.taxYear] {
            text = AppFormatting.editableDecimal(stored)
            markedAbsent = false
            compared = true
        } else if employer.codeTTIsAbsent(for: profile.taxYear) {
            markedAbsent = true
            compared = true
        }
    }

    private func compareAmount() {
        amountFocused = false
        message = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = AppFormatting.parseDecimal(trimmed), amount >= 0 else {
            message = "Enter the code TT amount as a dollar figure, or choose Not on my W-2."
            compared = false
            return
        }
        employer.setCodeTT(amount, for: profile.taxYear)
        try? modelContext.save()
        markedAbsent = false
        compared = true
        Haptics.success()
    }

    private func markAbsent() {
        amountFocused = false
        message = nil
        text = ""
        employer.markCodeTTNotOnW2(for: profile.taxYear)
        try? modelContext.save()
        markedAbsent = true
        compared = true
        Haptics.select()
    }
}
