import OvertimeCore
import SwiftData
import SwiftUI

enum OnboardingPage: Int, CaseIterable, Identifiable {
    case welcome
    case pay
    case overtime
    case filing
    case income
    case rate
    case hours
    case car
    case payoff

    var id: Int { rawValue }

    var usesSlider: Bool {
        self == .income || self == .hours
    }
}

struct OnboardingDraft {
    var isHourly: Bool?
    var paidOvertime: Bool?
    var filingStatus: FilingStatus?
    var annualIncome: Double = 65_000
    var rateText = ""
    var workweekStartsOn = 1
    var typicalOvertimeHours: Double = 5
    var wantsCar: Bool?
    var acceptedDisclaimer = false
}

struct OnboardingEstimate: Equatable {
    var weeklyPremium: Decimal
    var deduction: Decimal
    var taxSaved: Decimal
    var blocked: Bool
    var phaseoutZero: Bool
}

enum OnboardingMath {
    static let marginalPercent = 22
    static var marginalRate: Decimal { Decimal(marginalPercent) / 100 }

    /// Slider values are halves of an hour. Build the decimal from that count so a comma locale cannot break it.
    static func hours(_ value: Double) -> Decimal {
        Decimal(Int((value * 2).rounded())) / 2
    }

    static func magi(_ draft: OnboardingDraft) -> Decimal {
        Decimal(Int(draft.annualIncome.rounded()))
    }

    static func rate(_ draft: OnboardingDraft) -> Decimal {
        var text = draft.rateText
        if text.hasSuffix(".") { text.removeLast() }
        return AppFormatting.parseDecimal(text) ?? 0
    }

    /// One typical week, carried across the year with `projectedYearEndPremium` (that week's premium × 52),
    /// then the real cap and MAGI phase-out. Nothing here is written into the week log.
    static func estimate(_ draft: OnboardingDraft) -> OnboardingEstimate {
        let hourly = rate(draft)
        let overtime = hours(draft.typicalOvertimeHours)
        let week = WorkWeek(hoursWorked: 40 + overtime, hourlyRate: hourly)
        let result = OvertimeCalculator.compute(week)
        let projected = OvertimeCalculator.projectedYearEndPremium(
            ytdQualifiedPremium: result.qualifiedPremium,
            weeksLogged: 1
        )
        let status = draft.filingStatus ?? .single
        let blocked = draft.isHourly == false
            || draft.paidOvertime == false
            || status == .marriedFilingSeparately
        let raw = OvertimeCalculator.deduction(
            qualifiedOvertime: projected,
            filingStatus: status,
            magi: magi(draft),
            hasValidSSN: true
        )
        let deduction = blocked ? Decimal(0) : raw
        return OnboardingEstimate(
            weeklyPremium: result.qualifiedPremium,
            deduction: deduction,
            taxSaved: OvertimeCalculator.estimatedTaxSavings(deduction: deduction, marginalRate: marginalRate),
            blocked: blocked,
            phaseoutZero: !blocked && projected > 0 && deduction == 0
        )
    }

    static func kindness(_ draft: OnboardingDraft) -> String? {
        var lines: [String] = []
        if draft.isHourly == false {
            lines.append("A salaried exempt job usually doesn't qualify for the overtime deduction.")
        }
        if draft.paidOvertime == false {
            lines.append("Without time-and-a-half after 40 hours, the overtime estimate stays at $0.")
        }
        if draft.filingStatus == .marriedFilingSeparately {
            lines.append("Married filing separately doesn't qualify for the overtime deduction.")
        }
        if !lines.isEmpty {
            return lines.joined(separator: " ") + " That's okay. You can keep going, change this in Settings, and the car-loan estimate is separate."
        }
        let estimate = estimate(draft)
        if draft.typicalOvertimeHours == 0 {
            return "With no overtime hours, this yearly estimate is $0. Log a real week later and it can change."
        }
        if estimate.phaseoutZero {
            return "At this income, the estimate phases out to $0. It shrinks once income passes the threshold."
        }
        return nil
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft = OnboardingDraft()
    @State private var page = 0
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var celebrate = 0

    private let taxYear = TaxProfile.defaultTaxYear()
    private var pages: [OnboardingPage] { OnboardingPage.allCases }
    private var current: OnboardingPage { pages[page] }

    var body: some View {
        VStack(spacing: 0) {
            header
            pager
        }
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .sensoryFeedback(.selection, trigger: selectionTick)
        .sensoryFeedback(.success, trigger: celebrate)
        .onChange(of: page) { _, newValue in
            if pages[newValue] == .payoff {
                celebrate += 1
            }
        }
        .alert("Couldn't save", isPresented: saveAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button {
                    go(to: page - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(Theme.rounded(.body, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.card))
                        .overlay(Circle().stroke(Theme.cardStroke, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .disabled(isSaving)
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
            }
            OnboardingProgress(step: page, total: pages.count)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var pager: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(pages) { step in
                    pageView(step)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .accessibilityHidden(step != current)
                        .allowsHitTesting(step == current)
                }
            }
            .offset(x: -CGFloat(page) * geo.size.width)
            .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.08), value: page)
        }
        .clipped()
        .simultaneousGesture(swipe)
    }

    @ViewBuilder
    private func pageView(_ step: OnboardingPage) -> some View {
        switch step {
        case .welcome:
            OnboardingWelcomePage()
        case .pay:
            OnboardingPayPage(draft: $draft)
        case .overtime:
            OnboardingOvertimePayPage(draft: $draft)
        case .filing:
            OnboardingFilingPage(draft: $draft)
        case .income:
            OnboardingIncomePage(draft: $draft)
        case .rate:
            OnboardingRatePage(draft: $draft)
        case .hours:
            OnboardingHoursPage(draft: $draft)
        case .car:
            OnboardingCarPage(draft: $draft)
        case .payoff:
            OnboardingPayoffPage(draft: draft, isActive: current == .payoff)
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            if current == .payoff {
                Text(AppCopy.disclaimer)
                    .font(Theme.rounded(.footnote))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                gotItButton
            } else if !canAdvance, !disabledHint.isEmpty {
                Text(disabledHint)
                    .font(Theme.rounded(.caption))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            ThemeButton(title: buttonTitle, enabled: canAdvance, isLoading: isSaving) {
                primaryTapped()
            }
            .accessibilityHint(canAdvance ? "Continues" : payoffHint)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.cardStroke).frame(height: 1)
        }
    }

    private var gotItButton: some View {
        Button {
            draft.acceptedDisclaimer.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: draft.acceptedDisclaimer ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(draft.acceptedDisclaimer ? Theme.emerald : Theme.textSecondary)
                Text("Got it")
                    .font(Theme.rounded(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(draft.acceptedDisclaimer ? Theme.emerald.opacity(0.12) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(draft.acceptedDisclaimer ? Theme.emerald : Theme.cardStroke, lineWidth: draft.acceptedDisclaimer ? 2 : 1)
            )
        }
        .buttonStyle(PressableStyle())
        .disabled(isSaving)
        .sensoryFeedback(.selection, trigger: draft.acceptedDisclaimer)
        .accessibilityLabel("Got it")
        .accessibilityValue(draft.acceptedDisclaimer ? "Acknowledged" : "Not acknowledged")
        .accessibilityHint(AppCopy.disclaimer)
        .accessibilityAddTraits(draft.acceptedDisclaimer ? .isSelected : AccessibilityTraits())
    }

    private var buttonTitle: String {
        switch current {
        case .welcome: "Get started"
        case .payoff: "Let's go"
        default: "Continue"
        }
    }

    private var disabledHint: String {
        switch current {
        case .pay: "Choose hourly or salaried"
        case .overtime: "Choose yes or no"
        case .filing: "Choose a filing status"
        case .rate: "Enter an hourly rate to continue"
        case .car: "Choose yes or no"
        default: ""
        }
    }

    private var payoffHint: String {
        current == .payoff ? "Unavailable until you tap Got it" : "Unavailable until this step is answered"
    }

    private var canAdvance: Bool {
        switch current {
        case .welcome, .income, .hours:
            return true
        case .pay:
            return draft.isHourly != nil
        case .overtime:
            return draft.paidOvertime != nil
        case .filing:
            return draft.filingStatus != nil
        case .rate:
            return OnboardingMath.rate(draft) > 0
        case .car:
            return draft.wantsCar != nil
        case .payoff:
            return draft.acceptedDisclaimer
        }
    }

    private var selectionTick: String {
        [
            draft.isHourly.map { $0 ? "h1" : "h0" } ?? "h",
            draft.paidOvertime.map { $0 ? "o1" : "o0" } ?? "o",
            draft.filingStatus?.rawValue ?? "f",
            draft.wantsCar.map { $0 ? "c1" : "c0" } ?? "c"
        ].joined(separator: "|")
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 28, coordinateSpace: .local)
            .onEnded { value in
                guard !isSaving else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 72, abs(dx) > abs(dy) * 1.25 else { return }
                let fromEdge = value.startLocation.x < 24
                if dx > 0, page > 0, fromEdge || !current.usesSlider {
                    go(to: page - 1)
                } else if dx < 0, !current.usesSlider, current != .payoff, canAdvance {
                    go(to: page + 1)
                }
            }
    }

    private func primaryTapped() {
        if current == .payoff {
            save()
        } else {
            go(to: page + 1)
        }
    }

    private func go(to next: Int) {
        guard !isSaving, pages.indices.contains(next) else { return }
        if next > page, !canAdvance { return }
        page = next
    }

    private var saveAlertPresented: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private func save() {
        guard let filingStatus = draft.filingStatus,
              let isHourly = draft.isHourly,
              let paidOvertime = draft.paidOvertime,
              let wantsCar = draft.wantsCar,
              OnboardingMath.rate(draft) > 0,
              draft.acceptedDisclaimer,
              !isSaving else { return }

        isSaving = true
        let weekday = min(max(draft.workweekStartsOn, 1), 7)
        let profile = TaxProfile(
            taxYear: taxYear,
            filingStatus: filingStatus,
            estimatedMAGI: OnboardingMath.magi(draft),
            marginalRate: OnboardingMath.marginalRate,
            hasSSN: true,
            isHourlyNonExempt: isHourly,
            paidOvertimeOver40: paidOvertime,
            acceptedDisclaimer: true,
            wantsCarLoan: wantsCar
        )
        let employer = Employer(
            name: "Primary job",
            workweekStartsOn: weekday,
            defaultRate: OnboardingMath.rate(draft)
        )
        modelContext.insert(profile)
        modelContext.insert(employer)
        do {
            try modelContext.save()
        } catch {
            isSaving = false
            modelContext.delete(profile)
            modelContext.delete(employer)
            saveError = error.localizedDescription
        }
    }
}

private struct OnboardingProgress: View {
    var step: Int
    var total: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let fraction = CGFloat(step + 1) / CGFloat(max(total, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(Theme.goldBright)
                    .frame(width: max(12, geo.size.width * fraction))
            }
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel("Step \(step + 1) of \(total)")
        .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.12), value: step)
    }
}
