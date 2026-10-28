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
                    ContentUnavailableView(
                        "Setup incomplete",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The tax profile is missing.")
                    )
                }
            }
            .navigationTitle("Summary")
        }
    }

    private var locked: some View {
        List {
            Section {
                PremiumLockedSection(
                    message: "The combined Schedule 1-A estimate, the W-4 suggestion, and CSV export are locked."
                )
                Text(AppCopy.estimateFootnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loaded(_ profile: TaxProfile) -> some View {
        let estimate = ReturnEstimateBuilder.make(
            employer: employer,
            profile: profile,
            vehicles: vehicles,
            calendar: calendar
        )
        let csv = SummaryCSV.document(profile: profile, employer: employer, estimate: estimate)
        return List {
            Section {
                Text("Schedule 1-A, tax year \(String(profile.taxYear))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(AppFormatting.filingStatusTitle(profile.filingStatus))
                    .font(.subheadline)
            }

            Section("Overtime") {
                EstimateLine(title: "Year-to-date qualified premium (estimate)", amount: estimate.overtime.ytdQualifiedPremium)
                EstimateLine(
                    title: "Projected year-end premium (estimate)",
                    amount: estimate.overtime.projectedYearEndPremium,
                    detail: "Run-rate: average qualified premium of the logged weeks × 52."
                )
                EstimateLine(title: "Estimated overtime deduction", amount: estimate.overtime.estimatedDeduction)
                if let note = estimate.overtimeNote {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Car loan") {
                if estimate.carLines.isEmpty {
                    Text("No vehicle saved yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(estimate.carLines) { line in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.title)
                            Text(line.vin)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(line.included
                                 ? "Included in the deduction (estimate)"
                                 : "Not included. The checklist is not eligible.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

            Section("Schedule 1-A") {
                EstimateLine(title: "Combined estimated deduction", amount: estimate.schedule.combinedDeduction)
                EstimateLine(
                    title: "Estimated federal tax saved",
                    amount: estimate.schedule.estimatedTaxSaved,
                    detail: "Combined deduction × the \(AppFormatting.percent(profile.marginalRate)) bracket."
                )
                NavigationLink("W-4 line 4(b)") {
                    W4HelperView(profile: profile, estimate: estimate)
                }
                ShareLink(item: ScheduleCSV(text: csv), preview: SharePreview("Schedule 1-A estimate")) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
            }

            if let employer, let reported = employer.codeTT[profile.taxYear] {
                let difference = Schedule1ACalculator.compareCodeTT(
                    reported: reported,
                    computedPremium: estimate.overtime.ytdQualifiedPremium
                )
                Section("Code TT") {
                    EstimateLine(title: "W-2 Box 12 code TT", amount: reported)
                    EstimateLine(title: "Difference, code TT minus the log (estimate)", amount: difference.reportedMinusComputed)
                    Text(CodeTTCopy.explanation(difference: difference))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text(AppCopy.estimateFootnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct W4HelperView: View {
    let profile: TaxProfile
    let estimate: ReturnEstimate

    var body: some View {
        Form {
            Section {
                EstimateLine(title: "Estimated overtime deduction", amount: estimate.overtime.estimatedDeduction)
                EstimateLine(title: "Estimated car-loan deduction", amount: estimate.carDeduction)
                EstimateLine(title: "Suggested Form W-4 line 4(b) (estimate)", amount: estimate.w4Line4b)
            } footer: {
                Text("Line 4(b) is “Deductions” on Form W-4. This suggestion is the sum of the two estimated Schedule 1-A deductions, each already after its own cap and phase-out. It is not a full withholding calculation, and it does not fill out the form. Tax year \(String(profile.taxYear)), \(AppFormatting.filingStatusTitle(profile.filingStatus)).")
            }
            Section {
                Text(AppCopy.estimateFootnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("W-4 helper")
        .navigationBarTitleDisplayMode(.inline)
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
        add("meta", "estimated MAGI", profile.estimatedMAGI, "estimate")
        add("meta", "marginal rate", profile.marginalRate, "fraction, estimate")
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
        if let employer, let reported = employer.codeTT[profile.taxYear] {
            let difference = Schedule1ACalculator.compareCodeTT(
                reported: reported,
                computedPremium: estimate.overtime.ytdQualifiedPremium
            )
            add("code TT", "W-2 amount", reported, "entered from the W-2")
            add("code TT", "reported minus log", difference.reportedMinusComputed, "estimate")
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
