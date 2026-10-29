import OvertimeCore
import SwiftData
import SwiftUI

struct PaycheckTabView: View {
    @EnvironmentObject private var premium: PremiumStore
    @Query private var profiles: [TaxProfile]
    @Query private var employers: [Employer]
    @Query(sort: \Vehicle.vin) private var vehicles: [Vehicle]

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
            .navigationTitle("Paycheck")
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(premium)
            }
        }
    }

    private func content(profile: TaxProfile, employer: Employer) -> some View {
        let weeks = employer.loggedWeeks(taxYear: profile.taxYear, calendar: calendar)
        let ytd = OvertimeCalculator.ytdQualifiedPremium(weeks.map(\.workWeek))
        let typicalHours = employer.typicalOvertimeHours ?? 0
        let typicalWeek = OvertimeCalculator.compute(
            WorkWeek(hoursWorked: 40 + typicalHours, hourlyRate: employer.defaultRate)
        ).qualifiedPremium
        let projectedPremium = PaycheckCalculator.annualQualifiedPremium(
            logged: ytd,
            weeksLogged: weeks.count,
            typicalWeekPremium: typicalWeek
        )
        let blocked = OvertimeEligibility.blocksDeduction(profile) != nil
        let overtimeDeduction = blocked ? Decimal(0) : OvertimeCalculator.deduction(
            qualifiedOvertime: projectedPremium,
            filingStatus: profile.filingStatus,
            magi: profile.estimatedMAGI,
            hasValidSSN: profile.hasSSN
        )
        let car = premium.isPremium
            ? CarLoanMath.deduction(vehicles: vehicles, profile: profile, calendar: calendar)
            : 0
        let boost = PaycheckCalculator.boost(
            overtimeDeduction: overtimeDeduction,
            carLoanDeduction: car,
            filingStatus: profile.filingStatus,
            magi: profile.estimatedMAGI,
            frequency: profile.payFrequency,
            on: Date(),
            calendar: calendar
        )
        let usesTypicalWeek = weeks.isEmpty
        let weekStart = WorkweekDates.freeTierWeekStart(
            taxYear: profile.taxYear,
            weekday: employer.workweekStartsOn,
            now: Date(),
            calendar: calendar
        )
        let currentWeek = weeks.first { calendar.isDate($0.startDate, inSameDayAs: weekStart) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero(
                    boost: boost,
                    rate: boost.marginalRate,
                    includesCar: car > 0,
                    usesTypicalWeek: usesTypicalWeek,
                    typicalHours: typicalHours,
                    blocked: OvertimeEligibility.blocksDeduction(profile)
                )

                if premium.isPremium {
                    NavigationLink {
                        W4FlowView(
                            taxYear: profile.taxYear,
                            filingStatus: profile.filingStatus,
                            overtimeDeduction: overtimeDeduction,
                            carDeduction: car,
                            line4b: Schedule1ACalculator.suggestedW4Line4b(
                                overtimeDeduction: overtimeDeduction,
                                carLoanDeduction: car
                            )
                        )
                    } label: {
                        actionCard(
                            title: "Update my W-4",
                            subtitle: "Line 4(b) Deductions. An estimate of the amount to enter, plus how to send it.",
                            systemImage: "doc.text",
                            locked: false
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        CodeTTView(employer: employer, profile: profile, weeks: weeks)
                    } label: {
                        actionCard(
                            title: "Check my W-2 (Code TT)",
                            subtitle: "Compare Box 12 code TT with the qualified premium in this log.",
                            systemImage: "checkmark.seal",
                            locked: false
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { showPaywall = true } label: {
                        actionCard(
                            title: "Update my W-4",
                            subtitle: "Line 4(b) Deductions is part of Pro.",
                            systemImage: "doc.text",
                            locked: true
                        )
                    }
                    .buttonStyle(.plain)
                    Button { showPaywall = true } label: {
                        actionCard(
                            title: "Check my W-2 (Code TT)",
                            subtitle: "The Code TT check is part of Pro.",
                            systemImage: "checkmark.seal",
                            locked: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                weekCard(employer: employer, profile: profile, week: currentWeek, weekStart: weekStart)

                Text(premium.isPremium
                     ? "Earlier weeks are on the Hours tab."
                     : "Earlier weeks are part of Pro. This week stays free.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(AppCopy.estimateFootnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationDestination(for: WeekRoute.self) { route in
            WeekEditorView(
                route: route,
                employer: employer,
                taxYear: profile.taxYear,
                locksDate: !premium.isPremium
            )
        }
    }

    private func hero(boost: PaycheckBoost, rate: Decimal, includesCar: Bool, usesTypicalWeek: Bool, typicalHours: Decimal, blocked: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
                .foregroundStyle(Theme.gold)
            Text(AppFormatting.currency(boost.perPaycheck))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
            Text("more per paycheck")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(usesTypicalWeek
                 ? "Projection from a typical week of \(AppFormatting.hours(typicalHours)) overtime hours, not logged time. Spread over \(boost.remainingPaychecks) remaining \(AppFormatting.payFrequencyTitle(boost.payFrequency).lowercased()) paychecks this year."
                 : "Logged premium plus that pace for the rest of a 52-week year, spread over \(boost.remainingPaychecks) remaining \(AppFormatting.payFrequencyTitle(boost.payFrequency).lowercased()) paychecks.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
            Text("About \(AppFormatting.currency(boost.annualTaxSaved)) for the year. Estimated \(AppFormatting.percent(rate)) bracket on taxable income after the 2026 standard deduction and these deductions.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.9))
            if includesCar {
                Text("Includes an estimated car-loan interest deduction.")
                    .font(.footnote)
                    .foregroundStyle(Theme.gold)
            } else if !premium.isPremium {
                Text("Car-loan interest is part of Pro and is not in this number.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            }
            if let blocked {
                Text(blocked)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
            } else if usesTypicalWeek {
                Text("Log a real week and this switches to your hours. Estimate only, not tax advice.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.heroGradient)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("About \(AppFormatting.currency(boost.perPaycheck)) more per paycheck, estimate")
    }

    private func actionCard(title: String, subtitle: String, systemImage: String, locked: Bool) -> some View {
        SoftCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Theme.emerald)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: locked ? "lock.fill" : "chevron.right")
                    .foregroundStyle(locked ? Theme.gold : Color.secondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func weekCard(employer: Employer, profile: TaxProfile, week: Week?, weekStart: Date) -> some View {
        NavigationLink(value: weekRoute(week)) {
            SoftCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("This week")
                            .font(.headline)
                        Spacer()
                        Text(week == nil ? "Log hours" : "Edit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.emerald)
                    }
                    Text(AppFormatting.mediumDate(week?.startDate ?? weekStart))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let week {
                        Text("\(AppFormatting.hours(week.hoursWorked)) hours")
                            .font(.title3.weight(.semibold))
                        Text("Qualified premium (estimate) \(AppFormatting.currency(week.result.qualifiedPremium))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No hours logged for the current workweek.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("The free log is this week. Qualified premium is only the 0.5× FLSA premium.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func weekRoute(_ week: Week?) -> WeekRoute {
        if let week {
            return WeekRoute(kind: .edit(week.persistentModelID))
        }
        return WeekRoute(kind: .create)
    }
}
