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

private enum OvertimeDestination: Hashable {
    case week(WeekRoute)
    case codeTT
}

struct OvertimeTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premium: PremiumStore
    @Query private var profiles: [TaxProfile]
    @Query private var employers: [Employer]

    @State private var path: [OvertimeDestination] = []
    @State private var showPaywall = false

    private var calendar: Calendar { .current }

    private var profile: TaxProfile? {
        profiles.first(where: \.acceptedDisclaimer) ?? profiles.first
    }

    private var employer: Employer? {
        employers.first { $0.name == "Primary job" } ?? employers.first
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let profile, let employer {
                    content(profile: profile, employer: employer)
                } else {
                    ContentUnavailableView {
                        Label("Almost there", systemImage: "clock.fill")
                    } description: {
                        Text("The tax profile or primary job is missing.")
                    }
                }
            }
            .navigationTitle("Hours")
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
        let canCreate = premium.isPremium || visible.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 16) {
                    OvertimeDial(
                        amount: dialAmount,
                        cap: cap,
                        caption: dialCaption(profile: profile, cap: cap, hasWeeks: !visible.isEmpty),
                        accessibilityLabel: premium.isPremium
                            ? "Estimated year-to-date qualified overtime premium"
                            : "Estimated current-week qualified overtime premium"
                    )

                    if let note = OvertimeEligibility.blocksDeduction(profile) {
                        KindNote(text: note)
                    }

                    SoftCard {
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
                                detail: "Estimated tax before this deduction minus tax after it. 2026 brackets, standard deduction, floored at zero. Estimate."
                            )
                        } else {
                            EstimateLine(
                                title: "Current week qualified premium (estimate)",
                                amount: dialAmount
                            )
                            PremiumLockedSection(
                                message: "History beyond the current week, the year-to-date total, and the year-end estimate are part of Pro."
                            )
                        }
                        EstimateFootnote()
                    }
                }

                ThemeSectionHeader("Your weeks")
                if visible.isEmpty {
                    emptyWeeks(canCreate: canCreate)
                } else {
                    ForEach(visible) { week in
                        weekCard(week)
                    }
                }
                Text("Qualified premium is only the 0.5× FLSA premium on hours over 40. It is not the full time-and-a-half paycheck.")
                    .font(Theme.rounded(.footnote))
                    .foregroundStyle(Theme.textSecondary)

                Button {
                    if premium.isPremium {
                        path.append(.codeTT)
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Theme.emerald, Theme.gold)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("W-2 code TT")
                                .font(Theme.rounded(.headline, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text("Compare Box 12 with this log")
                                .font(Theme.rounded(.subheadline))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: premium.isPremium ? "chevron.right" : "lock.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityHidden(true)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Theme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Theme.cardStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(PressableStyle())
                .sensoryFeedback(.selection, trigger: path.count)
                Text("See how a code TT amount compares with the qualified premium this log computed. Estimate only, not tax advice.")
                    .font(Theme.rounded(.footnote))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .themeScreen()
        .navigationDestination(for: OvertimeDestination.self) { destination in
            switch destination {
            case .week(let route):
                WeekEditorView(
                    route: route,
                    employer: employer,
                    taxYear: profile.taxYear,
                    locksDate: !premium.isPremium
                )
            case .codeTT:
                CodeTTView(employer: employer, profile: profile, weeks: allWeeks)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addWeek(canCreate: canCreate)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add workweek")
            }
        }
    }

    private func emptyWeeks(canCreate: Bool) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.emerald)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Theme.goldBright)
                    .offset(x: 30, y: 24)
            }
            .accessibilityHidden(true)
            .padding(.top, 8)

            Text("Your overtime lives here")
                .font(Theme.rounded(.title2, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(premium.isPremium
                 ? "Log a workweek and we'll estimate the extra half-time pay."
                 : "Log this week's hours. Earlier weeks are part of Pro.")
                .font(Theme.rounded(.body))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            ThemeButton(title: "Log your first week", enabled: true) {
                addWeek(canCreate: canCreate)
            }
            .accessibilityHint("Opens the week editor")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func dialCaption(profile: TaxProfile, cap: Decimal, hasWeeks: Bool) -> String {
        if !hasWeeks { return "Log a week and the ring starts to fill" }
        if profile.filingStatus == .marriedFilingSeparately {
            return "Cap \(AppFormatting.currency(0)) for married filing separately"
        }
        let scope = premium.isPremium ? "Year to date" : "This week"
        return "\(scope), of a \(AppFormatting.currency(cap)) cap. Estimate."
    }

    private func weekCard(_ week: Week) -> some View {
        HStack(alignment: .top, spacing: 8) {
            NavigationLink(value: OvertimeDestination.week(WeekRoute(kind: .edit(week.persistentModelID)))) {
                weekRow(week)
            }
            .buttonStyle(.plain)
            Button {
                Haptics.select()
                modelContext.delete(week)
                try? modelContext.save()
            } label: {
                Image(systemName: "trash")
                    .font(Theme.rounded(.body, weight: .bold))
                    .foregroundStyle(Theme.deepTeal)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.backgroundElevated))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Delete week starting \(AppFormatting.mediumDate(week.startDate))")
        }
    }

    private func weekRow(_ week: Week) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppFormatting.mediumDate(week.startDate))
                .font(Theme.rounded(.headline, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("\(AppFormatting.hours(week.hoursWorked)) hours")
                .font(Theme.rounded(.subheadline))
                .foregroundStyle(Theme.textSecondary)
            Text(AppFormatting.currency(week.result.qualifiedPremium))
                .font(Theme.rounded(.title3, weight: .bold))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text("Qualified premium, estimate")
                .font(Theme.rounded(.caption, weight: .semibold))
                .foregroundStyle(Theme.emerald)
            Text("Regular rate, estimate \(AppFormatting.currency(week.result.regularRate))")
                .font(Theme.rounded(.subheadline))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.card)
                .shadow(color: Theme.shadowColor, radius: 10, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.cardStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func addWeek(canCreate: Bool) {
        if canCreate {
            path.append(.week(WeekRoute(kind: .create)))
        } else {
            showPaywall = true
        }
    }

}

private struct OvertimeDial: View {
    var amount: Decimal
    var cap: Decimal
    var caption: String
    var accessibilityLabel: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var amountSize: CGFloat = 32

    private var progress: Double {
        EstimateProgress.fraction(amount: amount, cap: cap)
    }

    private var accessibilityValue: String {
        if cap == 0 {
            return "\(AppFormatting.currency(amount)). Estimate. Cap is \(AppFormatting.currency(0))."
        }
        return "\(AppFormatting.currency(amount)) of \(AppFormatting.currency(cap)) cap. Estimate."
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: 0x14C472), Color(hex: 0x0A9F5A), Color(hex: 0x004D4D)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.goldBright, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .spring(duration: 0.85, bounce: 0.2), value: progress)
                VStack(spacing: 2) {
                    Text(AppFormatting.currency(amount))
                        .font(.system(size: amountSize, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .snappy, value: amount)
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                    Text("Estimate")
                        .font(Theme.rounded(.caption, weight: .semibold))
                        .foregroundStyle(Theme.emerald)
                }
                .padding(28)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 280)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)

            Text(caption)
                .font(Theme.rounded(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
