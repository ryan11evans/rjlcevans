import OvertimeCore
import SwiftUI

struct OnboardingQuestion<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(Theme.rounded(.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(Theme.rounded(.body))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct OnboardingWelcomePage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                StopwatchHero()
                    .padding(.top, 12)
                Text("Get your overtime tax break in every paycheck")
                    .font(Theme.rounded(.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("See an estimate of the federal tax the qualified overtime deduction could leave in each paycheck, then put that amount on Form W-4 line 4(b). Interest on a new car loan can be part of it too. Estimates only, not tax advice.")
                    .font(Theme.rounded(.body))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct OnboardingPayPage: View {
    @Binding var draft: OnboardingDraft
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingQuestion(
            title: "How do you get paid?",
            subtitle: "Hourly, non-exempt work is the path that can qualify. A salary can still come along for the rest of the app."
        ) {
            VStack(spacing: 12) {
                ChoiceCard(
                    title: "Hourly",
                    subtitle: "Paid by the hour, and not exempt.",
                    symbol: "clock.fill",
                    isSelected: draft.isHourly == true
                ) {
                    draft.isHourly = true
                }
                ChoiceCard(
                    title: "Salaried",
                    subtitle: "A set salary. Exempt roles usually don't qualify.",
                    symbol: "briefcase.fill",
                    isSelected: draft.isHourly == false
                ) {
                    draft.isHourly = false
                }
                if draft.isHourly == false {
                    KindNote(text: "If the salary is exempt, the overtime deduction usually doesn't apply. That's okay — keep going. The car-loan estimate is separate, and you can switch this later in Settings if the job is actually hourly.")
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.1), value: draft.isHourly)
        }
    }
}

struct OnboardingOvertimePayPage: View {
    @Binding var draft: OnboardingDraft
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingQuestion(
            title: "Do you get time-and-a-half after 40 hours?",
            subtitle: "The deduction is only that extra half-time pay. Daily overtime and double-time don't count."
        ) {
            VStack(spacing: 12) {
                ChoiceCard(
                    title: "Yes",
                    subtitle: "Hours past 40 in the week are paid at time-and-a-half.",
                    symbol: "plus.circle.fill",
                    isSelected: draft.paidOvertime == true
                ) {
                    draft.paidOvertime = true
                }
                ChoiceCard(
                    title: "No",
                    subtitle: "No weekly overtime pay, or only daily or double-time.",
                    symbol: "moon.zzz.fill",
                    isSelected: draft.paidOvertime == false
                ) {
                    draft.paidOvertime = false
                }
                if draft.paidOvertime == false {
                    KindNote(text: "This one is only the extra half-pay after 40 hours in a week. If you don't get that, the overtime estimate stays at $0. You're welcome to keep going.")
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.1), value: draft.paidOvertime)
        }
    }
}

struct OnboardingFilingPage: View {
    @Binding var draft: OnboardingDraft
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingQuestion(
            title: "How do you file?",
            subtitle: "This sets the cap on the estimate. You can change it later in Settings."
        ) {
            VStack(spacing: 12) {
                ForEach(Self.choices, id: \.status) { choice in
                    ChoiceCard(
                        title: choice.title,
                        subtitle: choice.subtitle,
                        symbol: choice.symbol,
                        isSelected: draft.filingStatus == choice.status
                    ) {
                        draft.filingStatus = choice.status
                    }
                }
                if draft.filingStatus == .marriedFilingSeparately {
                    KindNote(text: "Filing separately means the overtime estimate stays at $0. Married filing jointly is the status that qualifies. You can change this anytime in Settings, and the car-loan estimate stands on its own.")
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.1), value: draft.filingStatus)
        }
    }

    private struct Choice {
        var status: FilingStatus
        var title: String
        var subtitle: String
        var symbol: String
    }

    private static let choices: [Choice] = [
        Choice(status: .single, title: "Single", subtitle: "Cap of $12,500 on the estimate.", symbol: "person.fill"),
        Choice(status: .marriedFilingJointly, title: "Married filing jointly", subtitle: "Cap of $25,000 on the estimate.", symbol: "person.2.fill"),
        Choice(status: .marriedFilingSeparately, title: "Married filing separately", subtitle: "The overtime estimate stays at $0.", symbol: "person.2.slash"),
        Choice(status: .headOfHousehold, title: "Head of household", subtitle: "Cap of $12,500 on the estimate.", symbol: "house.fill"),
        Choice(status: .qualifyingSurvivingSpouse, title: "Qualifying surviving spouse", subtitle: "Cap of $12,500 on the estimate.", symbol: "heart.fill")
    ]
}

struct OnboardingIncomePage: View {
    @Binding var draft: OnboardingDraft
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 52

    var body: some View {
        OnboardingQuestion(
            title: "Roughly how much do you make a year?",
            subtitle: "A ballpark is perfect. This stands in for estimated modified adjusted gross income, and it only shapes the phase-out."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppFormatting.currency(OnboardingMath.magi(draft)))
                    .font(.system(size: amountSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy, value: Int(draft.annualIncome.rounded()))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                Text("Estimated yearly income")
                    .font(Theme.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.emerald)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                Slider(value: $draft.annualIncome, in: 0...600_000, step: 1_000)
                    .tint(Theme.emerald)
                    .accessibilityLabel("Estimated yearly income")
                    .accessibilityValue(AppFormatting.currency(OnboardingMath.magi(draft)))

                HStack {
                    Text("$0")
                    Spacer()
                    Text("$600,000")
                }
                .font(Theme.rounded(.caption))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)

                if let status = draft.filingStatus,
                   status != .marriedFilingSeparately,
                   OnboardingMath.magi(draft) > status.phaseOutThreshold {
                    KindNote(text: "Above \(AppFormatting.currency(status.phaseOutThreshold)), the estimate shrinks a little for each extra $1,000. Still just an estimate.")
                }
            }
        }
    }
}

struct OnboardingRatePage: View {
    @Binding var draft: OnboardingDraft
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 64

    private var salaried: Bool { draft.isHourly == false }

    var body: some View {
        OnboardingQuestion(
            title: salaried ? "What's a rough hourly equivalent?" : "What's your hourly rate?",
            subtitle: salaried
                ? "Enough to keep the estimate ready if this job changes."
                : "Straight time, before the extra half. Shift differentials can wait until you log a week."
        ) {
            VStack(spacing: 16) {
                Text(rateDisplay)
                    .font(.system(size: amountSize, weight: .bold, design: .rounded))
                    .foregroundStyle(draft.rateText.isEmpty ? Theme.textSecondary : Theme.ink)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(salaried ? "Hourly equivalent" : "Hourly rate")
                    .accessibilityValue(rateDisplay)
                    .accessibilityAdjustableAction { direction in
                        let current = OnboardingMath.rate(draft)
                        let next: Decimal
                        switch direction {
                        case .increment:
                            next = min(9_999, current + 1)
                        case .decrement:
                            next = max(0, current - 1)
                        @unknown default:
                            return
                        }
                        setRate(next == 0 ? "" : AppFormatting.editableDecimal(next))
                    }

                ratePad

                workweekRow
                Text("A fixed 7-day week, not your payday.")
                    .font(Theme.rounded(.caption))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var rateDisplay: String {
        draft.rateText.isEmpty ? "$0" : "$\(draft.rateText)"
    }

    private var ratePad: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { column in
                        rateKey(Self.keys[row * 3 + column])
                    }
                }
            }
        }
    }

    private func rateKey(_ key: String) -> some View {
        Button {
            tap(key)
        } label: {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left")
                        .font(Theme.rounded(.title3, weight: .semibold))
                } else {
                    Text(key)
                        .font(Theme.rounded(.title2, weight: .semibold))
                }
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(key == "⌫" ? "Delete" : key == "." ? "Decimal point" : key)
    }

    private var workweekRow: some View {
        Menu {
            Picker("Workweek starts", selection: $draft.workweekStartsOn) {
                ForEach(1...7, id: \.self) { day in
                    Text(AppFormatting.weekdayName(day)).tag(day)
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workweek starts")
                        .font(Theme.rounded(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                    Text(AppFormatting.weekdayName(draft.workweekStartsOn))
                        .font(Theme.rounded(.headline, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(Theme.emerald)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
        }
        .accessibilityLabel("Workweek starts")
        .accessibilityValue(AppFormatting.weekdayName(draft.workweekStartsOn))
    }

    private static let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]

    private func tap(_ key: String) {
        var text = draft.rateText
        if key == "⌫" {
            if !text.isEmpty { text.removeLast() }
        } else if key == "." {
            if text.contains(".") { return }
            if text.isEmpty { text = "0" }
            text.append(".")
        } else if let dot = text.firstIndex(of: ".") {
            let decimals = text.distance(from: text.index(after: dot), to: text.endIndex)
            if decimals >= 2 { return }
            text.append(key)
        } else if text == "0" {
            text = key
        } else if text.count >= 4 {
            return
        } else {
            text.append(key)
        }
        setRate(text)
    }

    private func setRate(_ text: String) {
        if reduceMotion {
            draft.rateText = text
        } else {
            withAnimation(.snappy) { draft.rateText = text }
        }
    }
}

struct OnboardingFrequencyPage: View {
    @Binding var draft: OnboardingDraft
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingQuestion(
            title: "How often are you paid?",
            subtitle: "This spreads the yearly estimate across the paychecks still left this year. It is an estimate of pay dates, not your employer's calendar."
        ) {
            VStack(spacing: 12) {
                frequencyCard(.weekly, symbol: "calendar")
                frequencyCard(.biweekly, symbol: "calendar.badge.clock")
                frequencyCard(.semimonthly, symbol: "calendar.badge.plus")
                frequencyCard(.monthly, symbol: "calendar.circle")
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.1), value: draft.payFrequency)
        }
    }

    private func frequencyCard(_ frequency: PayFrequency, symbol: String) -> some View {
        ChoiceCard(
            title: AppFormatting.payFrequencyTitle(frequency),
            subtitle: AppFormatting.payFrequencyDetail(frequency),
            symbol: symbol,
            isSelected: draft.payFrequency == frequency
        ) {
            draft.payFrequency = frequency
        }
    }
}

struct OnboardingHoursPage: View {
    @Binding var draft: OnboardingDraft
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 56

    private var estimate: OnboardingEstimate { OnboardingMath.estimate(draft) }

    var body: some View {
        OnboardingQuestion(
            title: "Typical overtime hours per week?",
            subtitle: "A usual week is enough. This preview is a projection, not logged hours, and it updates as you slide."
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    stepButton(symbol: "minus", label: "Fewer overtime hours") { nudge(-0.5) }
                    VStack(spacing: 2) {
                        Text(AppFormatting.hours(OnboardingMath.hours(draft.typicalOvertimeHours)))
                            .font(.system(size: amountSize, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : .snappy, value: draft.typicalOvertimeHours)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text("hours")
                            .font(Theme.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Typical overtime hours")
                    .accessibilityValue("\(AppFormatting.hours(OnboardingMath.hours(draft.typicalOvertimeHours))) hours")
                    stepButton(symbol: "plus", label: "More overtime hours") { nudge(0.5) }
                }

                Slider(value: $draft.typicalOvertimeHours, in: 0...20, step: 0.5)
                    .tint(Theme.gold)
                    .accessibilityLabel("Typical overtime hours per week")
                    .accessibilityValue("\(AppFormatting.hours(OnboardingMath.hours(draft.typicalOvertimeHours))) hours")

                previewCard
            }
        }
    }

    private func stepButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Theme.rounded(.title3, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.card))
                .overlay(Circle().stroke(Theme.cardStroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    private var previewCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("About")
                    .font(Theme.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                Text(AppFormatting.currency(estimate.perPaycheck))
                    .font(Theme.rounded(.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy, value: estimate.perPaycheck)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("more per paycheck")
                    .font(Theme.rounded(.title3, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Projection from this typical week, not logged hours. Estimate.")
                    .font(Theme.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Theme.emerald)
                Text("About \(AppFormatting.currency(estimate.taxSaved)) for the year")
                    .font(Theme.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.deepTeal)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy, value: estimate.taxSaved)
                Text("Estimated deduction \(AppFormatting.currency(estimate.deduction)). About \(AppFormatting.currency(estimate.weeklyPremium)) of qualified half-time premium in a week like this, carried across the year, then the cap and income phase-out. Spread over \(estimate.remainingPaychecks) remaining \(AppFormatting.payFrequencyTitle(draft.payFrequency ?? .biweekly).lowercased()) paychecks.")
                    .font(Theme.rounded(.footnote))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = OnboardingMath.kindness(draft) {
                    KindNote(text: note)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(previewLabel)
    }

    private var previewLabel: String {
        var text = "About \(AppFormatting.currency(estimate.perPaycheck)) more per paycheck. Projection from a typical week, not logged hours. Estimate. About \(AppFormatting.currency(estimate.taxSaved)) for the year."
        if let note = OnboardingMath.kindness(draft) {
            text += " \(note)"
        }
        return text
    }

    private func nudge(_ delta: Double) {
        let next = min(20, max(0, draft.typicalOvertimeHours + delta))
        let halves = (next * 2).rounded() / 2
        if reduceMotion {
            draft.typicalOvertimeHours = halves
        } else {
            withAnimation(.snappy) { draft.typicalOvertimeHours = halves }
        }
    }
}

struct OnboardingCarPage: View {
    @Binding var draft: OnboardingDraft
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingQuestion(
            title: "Bought a new car in 2025 or later?",
            subtitle: "Qualified interest on a new car loan is the other estimate. A yes just opens that tab later."
        ) {
            VStack(spacing: 12) {
                ChoiceCard(
                    title: "Yes",
                    subtitle: "We'll set up the car loan tab later. No VIN needed now.",
                    symbol: "car.fill",
                    isSelected: draft.wantsCar == true
                ) {
                    draft.wantsCar = true
                }
                ChoiceCard(
                    title: "No",
                    subtitle: "You can add a car whenever you want.",
                    symbol: "calendar",
                    isSelected: draft.wantsCar == false
                ) {
                    draft.wantsCar = false
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.1), value: draft.wantsCar)
        }
    }
}

struct OnboardingPayoffPage: View {
    var draft: OnboardingDraft
    var isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var estimate: OnboardingEstimate { OnboardingMath.estimate(draft) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    if estimate.deduction > 0 {
                        ParticleBurst(play: isActive)
                            .frame(height: 220)
                    }
                    VStack(spacing: 10) {
                        Image(systemName: estimate.deduction > 0 ? "sparkles" : "checkmark.seal.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Theme.gold, Theme.emerald)
                            .symbolEffect(.bounce, value: reduceMotion ? 0 : (isActive ? 1 : 0))
                            .accessibilityHidden(true)
                        Text("You did it")
                            .font(Theme.rounded(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("Here's the estimate from a typical week, in your paycheck first.")
                            .font(Theme.rounded(.body))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)
                }

                Text("About")
                    .font(Theme.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                CountingCurrency(target: estimate.perPaycheck, active: isActive, label: "About \(AppFormatting.currency(estimate.perPaycheck)) more per paycheck, estimate")
                Text("more per paycheck")
                    .font(Theme.rounded(.title3, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Projection from a typical week, not logged hours. Estimate.")
                    .font(Theme.rounded(.caption, weight: .bold))
                    .foregroundStyle(Theme.emerald)
                    .multilineTextAlignment(.center)

                Text("About")
                    .font(Theme.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 8)
                CountingCurrency(
                    target: estimate.taxSaved,
                    active: isActive,
                    delay: reduceMotion ? 0 : 1.25,
                    label: "About \(AppFormatting.currency(estimate.taxSaved)) for the year, estimate"
                )
                Text("for the year")
                    .font(Theme.rounded(.title3, weight: .bold))
                    .foregroundStyle(Theme.deepTeal)
                Text("Estimated \(AppFormatting.percent(estimate.marginalRate)) bracket. Taxable income is your income minus the 2026 standard deduction and this deduction, floored at zero. Savings are the difference in tax, so a bracket boundary is included. Estimate, not tax advice.")
                    .font(Theme.rounded(.footnote))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                if let note = OnboardingMath.kindness(draft) {
                    KindNote(text: note)
                }

                Text(draft.wantsCar == true
                     ? "The car loan tab is ready when you are. Bring the VIN when you have it."
                     : "No car right now. The Car Loan tab will be there if that changes.")
                    .font(Theme.rounded(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct CountingCurrency: View {
    var target: Decimal
    var active: Bool
    var delay: TimeInterval = 0
    var label: String = "Estimated amount"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0
    @State private var generation = 0

    var body: some View {
        AnimatingMoney(value: shown)
            .onAppear { sync(play: active) }
            .onChange(of: active) { _, play in sync(play: play) }
            .onChange(of: target) { _, _ in
                if active { sync(play: true) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(AppFormatting.currency(target))
    }

    private func sync(play: Bool) {
        generation += 1
        let token = generation
        let end = NSDecimalNumber(decimal: target).doubleValue
        if !play || reduceMotion {
            jump(to: play ? end : 0)
            return
        }
        jump(to: 0)
        let begin = {
            DispatchQueue.main.async {
                guard token == generation else { return }
                withAnimation(.spring(duration: 1.15, bounce: 0.18)) {
                    shown = end
                }
            }
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: begin)
        } else {
            begin()
        }
    }

    private func jump(to value: Double) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { shown = value }
    }
}

private struct AnimatingMoney: View, Animatable {
    var value: Double
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(AppFormatting.currency(Decimal(value)))
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }
}

private struct ParticleBurst: View {
    var play: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        Group {
            if play && !reduceMotion && !finished {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { context, size in
                        let time = timeline.date.timeIntervalSince(start)
                        guard time >= 0, time < 2.05 else { return }
                        let origin = CGPoint(x: size.width / 2, y: size.height * 0.72)
                        for index in 0..<26 {
                            let seed = Self.seed(index)
                            let x = origin.x + CGFloat(cos(seed.angle) * seed.speed * time)
                            let y = origin.y + CGFloat(sin(seed.angle) * seed.speed * time + 0.5 * 260 * time * time)
                            let fade = max(0, 1 - time / 1.85)
                            var mark = context
                            mark.opacity = fade
                            let rect = CGRect(x: x, y: y, width: seed.length, height: seed.round ? seed.length : seed.length * 1.7)
                            mark.fill(
                                Path(roundedRect: rect, cornerRadius: seed.round ? seed.length / 2 : 2),
                                with: .color(seed.color)
                            )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: play) {
            guard play, !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(2.2))
            finished = true
        }
        .onChange(of: play) { _, isPlaying in
            if isPlaying {
                start = Date()
                finished = false
            }
        }
    }

    private struct Seed {
        var angle: Double
        var speed: Double
        var length: CGFloat
        var round: Bool
        var color: Color
    }

    private static func seed(_ index: Int) -> Seed {
        func unit(_ salt: Int) -> Double {
            let raw = sin(Double(index * 97 + salt * 53)) * 43_758.5453
            return raw - floor(raw)
        }
        let colors = [
            Color(hex: 0xF5C542),
            Color(hex: 0x0A9F5A),
            Color(hex: 0x004D4D),
            Color(hex: 0xF0D48A)
        ]
        // Burst upward. Screen y grows downward, so the sine of a negative angle climbs.
        let angle = -.pi * (0.15 + unit(1) * 0.7)
        return Seed(
            angle: angle,
            speed: 150 + unit(2) * 170,
            length: CGFloat(6 + unit(3) * 7),
            round: unit(4) > 0.4,
            color: colors[index % colors.count]
        )
    }
}

extension OnboardingDraft {
    static var previewHappy: OnboardingDraft {
        var draft = OnboardingDraft()
        draft.isHourly = true
        draft.paidOvertime = true
        draft.filingStatus = .single
        draft.annualIncome = 65_000
        draft.rateText = "24"
        draft.typicalOvertimeHours = 5
        draft.payFrequency = .biweekly
        draft.wantsCar = true
        return draft
    }

    static var previewIneligible: OnboardingDraft {
        var draft = OnboardingDraft()
        draft.isHourly = false
        draft.paidOvertime = false
        draft.filingStatus = .marriedFilingSeparately
        draft.annualIncome = 80_000
        draft.rateText = "40"
        draft.typicalOvertimeHours = 8
        draft.payFrequency = .weekly
        draft.wantsCar = false
        return draft
    }
}

private struct OnboardingDraftHost<Content: View>: View {
    @State private var draft: OnboardingDraft
    private let content: (Binding<OnboardingDraft>) -> Content

    init(_ draft: OnboardingDraft = OnboardingDraft(), @ViewBuilder content: @escaping (Binding<OnboardingDraft>) -> Content) {
        _draft = State(initialValue: draft)
        self.content = content
    }

    var body: some View {
        content($draft)
            .background(Theme.background.ignoresSafeArea())
    }
}

#Preview("Welcome") {
    OnboardingWelcomePage()
        .background(Theme.background.ignoresSafeArea())
}

#Preview("Pay") {
    OnboardingDraftHost { OnboardingPayPage(draft: $0) }
}

#Preview("Overtime pay") {
    OnboardingDraftHost { OnboardingOvertimePayPage(draft: $0) }
}

#Preview("Filing status") {
    OnboardingDraftHost { OnboardingFilingPage(draft: $0) }
}

#Preview("Income") {
    OnboardingDraftHost(.previewHappy) { OnboardingIncomePage(draft: $0) }
}

#Preview("Hourly rate") {
    OnboardingDraftHost(.previewHappy) { OnboardingRatePage(draft: $0) }
}

#Preview("Typical hours") {
    OnboardingDraftHost(.previewHappy) { OnboardingHoursPage(draft: $0) }
}

#Preview("New car") {
    OnboardingDraftHost { OnboardingCarPage(draft: $0) }
}

#Preview("Payoff") {
    OnboardingPayoffPage(draft: .previewHappy, isActive: true)
        .background(Theme.background.ignoresSafeArea())
}

#Preview("Payoff, kindly ineligible") {
    OnboardingPayoffPage(draft: .previewIneligible, isActive: true)
        .background(Theme.background.ignoresSafeArea())
}
