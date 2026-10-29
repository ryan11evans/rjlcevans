import OvertimeCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SummaryTabView: View {
    @EnvironmentObject private var premium: PremiumStore
    @Query private var profiles: [TaxProfile]
    @Query private var employers: [Employer]
    @Query(sort: \Vehicle.vin) private var vehicles: [Vehicle]

    private var calendar: Calendar { .current }

    private var profile: TaxProfile? {
        profiles.first(where: \.acceptedDisclaimer) ?? profiles.first
    }

    private var employer: Employer? {
        employers.first { $0.name == "Primary job" } ?? employers.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile {
                    if premium.isPremium {
                        loaded(profile)
                    } else {
                        locked
                    }
                } else {
                    ContentUnavailableView {
                        Label("Almost there", systemImage: "chart.pie.fill")
                    } description: {
                        Text("The tax profile is missing.")
                    }
                }
            }
            .navigationTitle("Summary")
        }
    }

    private var locked: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 42))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.gold, Theme.emerald)
                    .accessibilityHidden(true)
                Text("The full picture is part of Pro")
                    .font(Theme.rounded(.title2, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                SoftCard {
                    PremiumLockedSection(
                        message: "The summary and CSV export are part of Pro."
                    )
                }
                EstimateFootnote()
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .themeScreen()
    }

    private func loaded(_ profile: TaxProfile) -> some View {
        let estimate = ReturnEstimateBuilder.make(
            employer: employer,
            profile: profile,
            vehicles: vehicles,
            calendar: calendar
        )
        let csv = SummaryCSV.document(profile: profile, employer: employer, estimate: estimate)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
            SoftCard {
                VStack(spacing: 6) {
                    Text("Estimated deduction")
                        .font(Theme.rounded(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                    ThemeMoney(amount: estimate.schedule.combinedDeduction, style: .largeTitle, alignment: .center)
                    Text("Estimate")
                        .font(Theme.rounded(.caption, weight: .semibold))
                        .foregroundStyle(Theme.emerald)
                    Text("Estimated tax saved \(AppFormatting.currency(estimate.schedule.estimatedTaxSaved))")
                        .font(Theme.rounded(.headline, weight: .bold))
                        .foregroundStyle(Theme.deepTeal)
                        .multilineTextAlignment(.center)
                    Text("Tax year \(String(profile.taxYear)) · \(AppFormatting.filingStatusTitle(profile.filingStatus))")
                        .font(Theme.rounded(.caption))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }

            SoftCard {
                VStack(alignment: .leading, spacing: 10) {
                ThemeSectionHeader("Overtime")
                EstimateLine(title: "Year-to-date qualified premium (estimate)", amount: estimate.overtime.ytdQualifiedPremium)
                EstimateLine(
                    title: "Projected year-end premium (estimate)",
                    amount: estimate.overtime.projectedYearEndPremium,
                    detail: "Run-rate: average qualified premium of the logged weeks × 52."
                )
                EstimateLine(title: "Estimated overtime deduction", amount: estimate.overtime.estimatedDeduction)
                if let note = estimate.overtimeNote {
                    Text(note)
                        .font(Theme.rounded(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                }
            }

            SoftCard {
                VStack(alignment: .leading, spacing: 10) {
                ThemeSectionHeader("Car loan")
                if estimate.carLines.isEmpty {
                    Text("No car yet. The Car Loan tab can check a VIN.")
                        .font(Theme.rounded(.body))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(estimate.carLines) { line in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.title)
                                .font(Theme.rounded(.headline, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text(line.vin)
                                .font(.caption.monospaced())
                                .foregroundStyle(Theme.textSecondary)
                            Text(line.included
                                 ? "Included in the deduction (estimate)"
                                 : "Not included. The checklist isn't eligible yet.")
                                .font(Theme.rounded(.caption))
                                .foregroundStyle(Theme.textSecondary)
                            EstimateLine(
                                title: line.usedForm1098 ? "Form 1098-VLI interest" : "Interest used (estimate)",
                                amount: line.used
                            )
                        }
                    }
                }
                EstimateLine(
                    title: "Estimated car-loan deduction",
                    amount: estimate.carDeduction,
                    detail: "$10,000 cap on the combined interest, then the MAGI phase-out."
                )
                }
            }

            SoftCard {
                VStack(alignment: .leading, spacing: 10) {
                ThemeSectionHeader("Schedule 1-A")
                EstimateLine(title: "Combined estimated deduction", amount: estimate.schedule.combinedDeduction)
                EstimateLine(
                    title: "Estimated federal tax saved",
                    amount: estimate.schedule.estimatedTaxSaved,
                    detail: "Estimated tax before these deductions minus tax after them. 2026 brackets and the standard deduction. Estimate."
                )
                NavigationLink("Update my W-4") {
                    W4FlowView(
                        taxYear: profile.taxYear,
                        filingStatus: profile.filingStatus,
                        overtimeDeduction: estimate.overtime.estimatedDeduction,
                        carDeduction: estimate.carDeduction,
                        line4b: estimate.w4Line4b
                    )
                }
                ShareLink(item: ScheduleCSV(text: csv), preview: SharePreview("Schedule 1-A estimate")) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                }
            }

            if let employer {
                let reported = employer.codeTT[profile.taxYear]
                let absent = employer.codeTTIsAbsent(for: profile.taxYear)
                if reported != nil || absent {
                    let comparison = Schedule1ACalculator.comparison(
                        reported: absent ? nil : reported,
                        computedPremium: estimate.overtime.ytdQualifiedPremium
                    )
                    SoftCard {
                        VStack(alignment: .leading, spacing: 10) {
                        ThemeSectionHeader("Code TT")
                        if let reported {
                            EstimateLine(title: "W-2 Box 12 code TT", amount: reported)
                        }
                        Text(CodeTTCopy.headline(comparison))
                            .font(Theme.rounded(.headline, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        if let dollars = CodeTTCopy.dollars(comparison) {
                            EstimateLine(title: "Dollar difference (estimate)", amount: dollars)
                        }
                        Text(CodeTTCopy.explanation(comparison: comparison, taxYear: profile.taxYear))
                            .font(Theme.rounded(.subheadline))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            EstimateFootnote()
            }
            .padding(20)
        }
        .themeScreen()
    }
}

enum SummaryCSV {
    static func document(profile: TaxProfile, employer: Employer?, estimate: ReturnEstimate) -> String {
        var rows: [[String]] = [["section", "label", "amount", "note"]]
        func add(_ section: String, _ label: String, _ amount: Decimal?, _ note: String) {
            rows.append([section, label, amount.map(AppFormatting.plainDecimal) ?? "", note])
        }
        add("meta", "disclaimer", nil, AppCopy.estimateFootnote)
        add("meta", "tax year", Decimal(profile.taxYear), "estimate")
        rows.append(["meta", "filing status", "", AppFormatting.filingStatusTitle(profile.filingStatus)])
        let tax = FederalBracket.estimate(
            magi: profile.estimatedMAGI,
            filingStatus: profile.filingStatus,
            schedule1ADeductions: estimate.schedule.combinedDeduction
        )
        add("meta", "estimated MAGI", profile.estimatedMAGI, "estimate")
        add("meta", "marginal rate", tax.marginalRate, "fraction, 2026 bracket at taxable income after the standard deduction and Schedule 1-A, estimate")
        add("meta", "standard deduction", tax.standardDeduction, "2026 basic standard deduction, estimate")
        rows.append(["meta", "pay frequency", "", profile.payFrequency.rawValue])
        let boost = PaycheckCalculator.boost(
            overtimeDeduction: estimate.overtime.estimatedDeduction,
            carLoanDeduction: estimate.carDeduction,
            filingStatus: profile.filingStatus,
            magi: profile.estimatedMAGI,
            frequency: profile.payFrequency,
            on: Date(),
            calendar: .current
        )
        add("paycheck", "estimated annual tax saved", boost.annualTaxSaved, "estimate")
        add("paycheck", "remaining paychecks", Decimal(boost.remainingPaychecks), "estimate")
        add("paycheck", "estimated per paycheck", boost.perPaycheck, "annual estimate divided by remaining paychecks")
        add("overtime", "year-to-date qualified premium", estimate.overtime.ytdQualifiedPremium, "estimate, 0.5x FLSA premium only")
        add("overtime", "projected year-end premium", estimate.overtime.projectedYearEndPremium, "estimate, average of logged weeks times 52")
        add("overtime", "estimated deduction", estimate.overtime.estimatedDeduction, "estimate, after cap and phase-out")
        add("overtime", "estimated federal tax saved", estimate.overtime.estimatedTaxSaved, "estimate")
        for line in estimate.carLines {
            add("car loan", "\(line.title) \(line.vin) interest used", line.used, line.usedForm1098 ? "Form 1098-VLI" : "estimate, projected")
            rows.append(["car loan", "\(line.vin) included", line.included ? "yes" : "no", "eligible loans only"])
        }
        add("car loan", "estimated deduction", estimate.carDeduction, "estimate, cap then phase-out")
        add("schedule 1-A", "combined estimated deduction", estimate.schedule.combinedDeduction, "estimate")
        add("schedule 1-A", "estimated federal tax saved", estimate.schedule.estimatedTaxSaved, "estimate")
        add("w-4", "suggested line 4(b)", estimate.w4Line4b, "estimate")
        if let employer {
            let reported = employer.codeTT[profile.taxYear]
            let absent = employer.codeTTIsAbsent(for: profile.taxYear)
            if reported != nil || absent {
                let comparison = Schedule1ACalculator.comparison(
                    reported: absent ? nil : reported,
                    computedPremium: estimate.overtime.ytdQualifiedPremium
                )
                if let reported {
                    add("code TT", "W-2 amount", reported, "entered from the W-2")
                }
                if absent {
                    rows.append(["code TT", "not on W-2", "", "user marked code TT as not on the W-2"])
                }
                if let gap = comparison.reportedMinusLog {
                    add("code TT", "reported minus log", gap, "estimate")
                }
            }
        }
        return rows.map { $0.map(csvCell).joined(separator: ",") }.joined(separator: "\n")
    }

    private static func csvCell(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

struct ScheduleCSV: Transferable, Sendable {
    var text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { csv in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("NewDeductions-Schedule1A-\(UUID().uuidString).csv")
            try Data(csv.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
