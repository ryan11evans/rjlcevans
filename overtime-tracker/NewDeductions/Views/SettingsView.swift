import OvertimeCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premium: PremiumStore
    @Query(sort: \TaxProfile.taxYear) private var profiles: [TaxProfile]
    @Query(sort: \Employer.name) private var employers: [Employer]

    @State private var confirmReset = false
    @State private var resetError: String?
    @State private var magiText = ""
    @State private var magiLoaded = false
    @State private var profileMessage: String?
    @State private var restoreMessage: String?
    @State private var showPaywall = false
    @State private var typicalHoursText = ""
    @State private var typicalLoaded = false
    @State private var hoursMessage: String?

    private var profile: TaxProfile? {
        profiles.first(where: \.acceptedDisclaimer) ?? profiles.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                CardBlock(title: "Disclaimer", footer: "Accepted during setup. The overtime, car-loan, and summary screens show a shorter line: \(AppCopy.estimateFootnote).") {
                    Text(AppCopy.disclaimer)
                        .font(Theme.rounded(.body))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let profile {
                    profileSection(profile)
                }

                if !employers.isEmpty {
                    CardBlock(title: "Employer", footer: "Typical overtime hours are a projection until a real week is logged. Overtime is calculated per employer. Hours at different jobs are not combined.") {
                        ForEach(employers) { employer in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(employer.name)
                                    .font(Theme.rounded(.headline, weight: .bold))
                                Text("\(AppFormatting.currency(employer.defaultRate)) / hour, estimate")
                                    .font(Theme.rounded(.subheadline))
                                    .foregroundStyle(Theme.textSecondary)
                                Picker("Workweek starts", selection: workweekBinding(employer)) {
                                    ForEach(1...7, id: \.self) { day in
                                        Text(AppFormatting.weekdayName(day)).tag(day)
                                    }
                                }
                                TextField("Typical overtime hours a week", text: $typicalHoursText)
                                    .keyboardType(.decimalPad)
                                Button("Save typical hours") { saveTypicalHours(employer) }
                                if let hoursMessage {
                                    Text(hoursMessage)
                                        .font(Theme.rounded(.footnote))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                CardBlock(title: "Purchase", footer: "New Deductions Pro is a one-time purchase. No subscription. Apple handles the payment. The price on the button is the price Apple shows.") {
                    LabeledContent("Access", value: premium.isPremium ? "Pro" : "Free")
                    if !premium.isPremium {
                        Text("Free includes the per-paycheck estimate, a VIN check, and the current week’s hours.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Unlock Pro") { showPaywall = true }
                    }
                    Button("Restore Purchases") {
                        Task { restoreMessage = await premium.restore() }
                    }
                }

                CardBlock(title: "Legal", footer: "These open in Safari. The app does not download them.") {
                    Link("Privacy Policy", destination: LegalURLs.privacy)
                    Link("Terms of Use", destination: LegalURLs.terms)
                    Link("Support", destination: LegalURLs.support)
                }

                CardBlock(title: "Overtime sources") {
                    ForEach(TaxSources.overtime) { source in
                        sourceLink(source)
                    }
                }

                CardBlock(title: "Car loan sources", footer: "These open in Safari when you tap them. The app does not download them.") {
                    ForEach(TaxSources.carLoan) { source in
                        sourceLink(source)
                    }
                }

                CardBlock(title: AppIdentity.displayName) {
                    LabeledContent("Version", value: versionText)
                    Text("Listed on the App Store as \(AppIdentity.appStoreName). The home screen name stays \(AppIdentity.displayName).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Estimates stay on this device. iCloud sync is off.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                CardBlock(title: "Reset", footer: "Deletes the tax profile, employer, weeks, and vehicles stored on this device.") {
                    Button("Reset onboarding", role: .destructive) {
                        confirmReset = true
                    }
                    .font(Theme.rounded(.headline, weight: .bold))
                }
                }
                .padding(20)
            }
            .themeScreen()
            .navigationTitle("Settings")
            .onAppear(perform: loadMAGI)
            .confirmationDialog("Reset onboarding?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Delete profile", role: .destructive) { resetStore() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes the tax profile, employer, weeks, and vehicles stored on this device.")
            }
            .alert("Couldn't reset", isPresented: resetAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resetError ?? "")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(premium)
            }
            .alert("Restore Purchases", isPresented: restoreAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func profileSection(_ profile: TaxProfile) -> some View {
        CardBlock(title: "Tax profile", footer: "Filing status, pay frequency, and estimated MAGI change the phase-out and the per-paycheck estimate. The bracket here is on MAGI minus the 2026 standard deduction, floored at zero. The paycheck estimate also subtracts the Schedule 1-A deductions and uses the difference in tax. Estimate, not tax advice.") {
            LabeledContent("Tax year", value: String(profile.taxYear))
            Picker("Filing status", selection: filingStatusBinding(profile)) {
                ForEach(FilingStatus.allCases, id: \.self) { status in
                    Text(AppFormatting.filingStatusTitle(status)).tag(status)
                }
            }
            Picker("Pay frequency", selection: payFrequencyBinding(profile)) {
                ForEach(PayFrequency.allCases, id: \.self) { frequency in
                    Text(AppFormatting.payFrequencyTitle(frequency)).tag(frequency)
                }
            }
            TextField("Estimated MAGI", text: $magiText)
                .keyboardType(.decimalPad)
            Button("Save estimated MAGI") { saveMAGI(profile) }
            LabeledContent(
                "Estimated federal bracket",
                value: AppFormatting.percent(
                    FederalBracket.estimate(
                        magi: AppFormatting.parseDecimal(magiText) ?? profile.estimatedMAGI,
                        filingStatus: profile.filingStatus,
                        schedule1ADeductions: 0
                    ).marginalRate
                )
            )
            Toggle("Valid Social Security number", isOn: boolBinding(profile, \.hasSSN))
            Toggle("Hourly and non-exempt", isOn: boolBinding(profile, \.isHourlyNonExempt))
            Toggle("Paid time-and-a-half after 40 hours", isOn: boolBinding(profile, \.paidOvertimeOver40))
            Toggle("Bought a new car in 2025 or later", isOn: wantsCarBinding(profile))
            if let profileMessage {
                Text(profileMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        if version.isEmpty { return build }
        if build.isEmpty { return version }
        return "\(version) (\(build))"
    }

    private var resetAlertPresented: Binding<Bool> {
        Binding(get: { resetError != nil }, set: { if !$0 { resetError = nil } })
    }

    private var restoreAlertPresented: Binding<Bool> {
        Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })
    }

    private func sourceLink(_ source: TaxSource) -> some View {
        Link(destination: source.url) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                Text(source.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadMAGI() {
        guard !magiLoaded, let profile else { return }
        magiLoaded = true
        magiText = AppFormatting.editableDecimal(profile.estimatedMAGI)
        guard !typicalLoaded else { return }
        typicalLoaded = true
        let employer = employers.first { $0.name == "Primary job" } ?? employers.first
        if let hours = employer?.typicalOvertimeHours {
            typicalHoursText = AppFormatting.editableDecimal(hours)
        }
    }

    private func saveTypicalHours(_ employer: Employer) {
        guard let hours = AppFormatting.parseDecimal(typicalHoursText), hours >= 0, hours <= 80 else {
            hoursMessage = "Enter typical overtime hours as a number from 0 to 80."
            return
        }
        employer.typicalOvertimeHours = hours
        hoursMessage = "Saved \(AppFormatting.hours(hours)) typical overtime hours. Estimate only."
        try? modelContext.save()
    }

    private func saveMAGI(_ profile: TaxProfile) {
        guard let magi = AppFormatting.parseDecimal(magiText), magi >= 0 else {
            profileMessage = "Enter estimated MAGI as a number."
            return
        }
        profile.estimatedMAGI = magi
        profile.marginalRate = FederalBracket.estimate(
            magi: magi,
            filingStatus: profile.filingStatus,
            schedule1ADeductions: 0
        ).marginalRate
        profileMessage = "Saved estimated MAGI \(AppFormatting.currency(magi))."
        try? modelContext.save()
    }

    private func payFrequencyBinding(_ profile: TaxProfile) -> Binding<PayFrequency> {
        Binding(
            get: { profile.payFrequency },
            set: { newValue in
                profile.payFrequency = newValue
                try? modelContext.save()
            }
        )
    }

    private func filingStatusBinding(_ profile: TaxProfile) -> Binding<FilingStatus> {
        Binding(
            get: { profile.filingStatus },
            set: { newValue in
                profile.filingStatus = newValue
                profile.marginalRate = FederalBracket.estimate(
                    magi: profile.estimatedMAGI,
                    filingStatus: newValue,
                    schedule1ADeductions: 0
                ).marginalRate
                try? modelContext.save()
            }
        )
    }

    private func wantsCarBinding(_ profile: TaxProfile) -> Binding<Bool> {
        Binding(
            get: { profile.wantsCarLoan ?? false },
            set: { newValue in
                profile.wantsCarLoan = newValue
                try? modelContext.save()
            }
        )
    }

    private func workweekBinding(_ employer: Employer) -> Binding<Int> {
        Binding(
            get: { employer.workweekStartsOn },
            set: { newValue in
                employer.workweekStartsOn = newValue
                try? modelContext.save()
            }
        )
    }

    private func boolBinding(_ profile: TaxProfile, _ keyPath: ReferenceWritableKeyPath<TaxProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { newValue in
                profile[keyPath: keyPath] = newValue
                try? modelContext.save()
            }
        )
    }

    private func resetStore() {
        do {
            let employers = try modelContext.fetch(FetchDescriptor<Employer>())
            employers.forEach(modelContext.delete)
            let vehicles = try modelContext.fetch(FetchDescriptor<Vehicle>())
            vehicles.forEach(modelContext.delete)
            let profiles = try modelContext.fetch(FetchDescriptor<TaxProfile>())
            profiles.forEach(modelContext.delete)
            try modelContext.save()
        } catch {
            resetError = error.localizedDescription
        }
    }
}
