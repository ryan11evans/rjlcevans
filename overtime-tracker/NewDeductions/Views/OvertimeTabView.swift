import OvertimeCore
import SwiftData
import SwiftUI

struct WeekRoute: Hashable {
    enum Kind: Hashable {
        case create
        case edit(PersistentIdentifier)
    }

    var kind: Kind
}

struct OvertimeTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premium: PremiumStore
    @Query private var profiles: [TaxProfile]
    @Query private var employers: [Employer]

    @State private var showPaywall = false

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
                if let profile, let employer {
                    content(profile: profile, employer: employer)
                } else {
                    ContentUnavailableView(
                        "Setup incomplete",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The tax profile or primary job is missing.")
                    )
                }
            }
            .navigationTitle("Overtime")
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(premium)
            }
        }
    }

    @ViewBuilder
    private func content(profile: TaxProfile, employer: Employer) -> some View {
        let allWeeks = employer.loggedWeeks(taxYear: profile.taxYear, calendar: calendar)
        let freeStart = WorkweekDates.freeTierWeekStart(
            taxYear: profile.taxYear,
            weekday: employer.workweekStartsOn,
            now: Date(),
            calendar: calendar
        )
        let visible = premium.isPremium
            ? allWeeks
            : allWeeks.filter { calendar.isDate($0.startDate, inSameDayAs: freeStart) }
        let estimate = OvertimeEligibility.yearEstimate(weeks: allWeeks, profile: profile)
        let dialAmount = premium.isPremium ? estimate.ytdQualifiedPremium : (visible.first?.result.qualifiedPremium ?? 0)
        let cap = OvertimeEligibility.cap(profile)

        List {
            Section {
                OvertimeDial(
                    amount: dialAmount,
                    cap: cap,
                    caption: dialCaption(profile: profile, cap: cap, hasWeeks: !visible.isEmpty),
                    accessibilityLabel: premium.isPremium
                        ? "Estimated year-to-date qualified overtime premium"
                        : "Estimated current-week qualified overtime premium"
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                if let note = OvertimeEligibility.blocksDeduction(profile) {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if premium.isPremium {
                    // Projection method: OvertimeCalculator.projectedYearEndPremium (logged-week average × 52).
                    EstimateLine(
                        title: "Year-to-date qualified premium (estimate)",
                        amount: estimate.ytdQualifiedPremium
                    )
                    EstimateLine(
                        title: "Projected year-end premium (estimate)",
                        amount: estimate.projectedYearEndPremium,
                        detail: "Run-rate: average qualified premium of the logged weeks × 52."
                    )
                    EstimateLine(
                        title: "Estimated deduction after phase-out",
                        amount: estimate.estimatedDeduction,
                        detail: "Cap, then $100 off per $1,000 of MAGI over the threshold. Uses the projected premium."
                    )
                    EstimateLine(
                        title: "Estimated federal tax saved",
                        amount: estimate.estimatedTaxSaved,
                        detail: "Estimated deduction × the \(AppFormatting.percent(profile.marginalRate)) bracket on the tax profile."
                    )
                } else {
                    EstimateLine(
                        title: "Current week qualified premium (estimate)",
                        amount: dialAmount
                    )
                    PremiumLockedSection(
                        message: "The year-to-date total, the year-end run-rate, the phase-out, and earlier weeks are locked."
                    )
                }

                Text(AppCopy.estimateFootnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                if visible.isEmpty {
                    ContentUnavailableView {
                        Label("No weeks logged", systemImage: "calendar.badge.plus")
                    } description: {
                        Text(premium.isPremium
                             ? "Add a workweek to estimate the FLSA half-time premium."
                             : "Add the current workweek. Earlier weeks are part of the full estimate.")
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(visible) { week in
                        NavigationLink(value: WeekRoute(kind: .edit(week.persistentModelID))) {
                            weekRow(week)
                        }
                    }
                    .onDelete { offsets in
                        delete(visible, at: offsets)
                    }
                }
            } header: {
                Text("Workweeks")
            } footer: {
                Text("Qualified premium is only the 0.5× FLSA premium on hours over 40. It is not the full time-and-a-half pay.")
            }

            Section {
                if premium.isPremium {
                    NavigationLink("W-2 Box 12 code TT") {
                        CodeTTView(employer: employer, profile: profile, weeks: allWeeks)
                    }
                } else {
                    Button("W-2 Box 12 code TT") { showPaywall = true }
                }
            } footer: {
                Text("Compare a code TT amount to the qualified premium this log computed.")
            }
        }
        .navigationDestination(for: WeekRoute.self) { route in
            WeekEditorView(
                route: route,
                employer: employer,
                taxYear: profile.taxYear,
                locksDate: !premium.isPremium
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if premium.isPremium || visible.isEmpty {
                    NavigationLink(value: WeekRoute(kind: .create)) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add workweek")
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add workweek")
                }
            }
        }
    }

    private func dialCaption(profile: TaxProfile, cap: Decimal, hasWeeks: Bool) -> String {
        if !hasWeeks { return "No weeks logged" }
        if profile.filingStatus == .marriedFilingSeparately {
            return "Cap \(AppFormatting.currency(0)). Married filing separately."
        }
        let scope = premium.isPremium ? "Year to date" : "Current week"
        return "\(scope) of \(AppFormatting.currency(cap)) cap"
    }

    private func weekRow(_ week: Week) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppFormatting.mediumDate(week.startDate))
                .font(.headline)
            Text("\(AppFormatting.hours(week.hoursWorked)) hours")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Regular rate (estimate) \(AppFormatting.currency(week.result.regularRate))")
                .font(.subheadline)
            Text("Qualified premium (estimate) \(AppFormatting.currency(week.result.qualifiedPremium))")
                .font(.subheadline)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func delete(_ weeks: [Week], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(weeks[index])
        }
        try? modelContext.save()
    }
}

private struct OvertimeDial: View {
    var amount: Decimal
    var cap: Decimal
    var caption: String
    var accessibilityLabel: String

    private var progress: Double {
        EstimateProgress.fraction(amount: amount, cap: cap)
    }

    private var accessibilityValue: String {
        if cap == 0 {
            return "\(AppFormatting.currency(amount)). Cap is \(AppFormatting.currency(0))."
        }
        return "\(AppFormatting.currency(amount)) of \(AppFormatting.currency(cap)) cap."
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(AppFormatting.currency(amount))
                        .font(.title2.weight(.semibold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("Estimate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(28)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)

            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
