import OvertimeCore
import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var step = 0
    @State private var isHourly: Bool?
    @State private var paidOvertime: Bool?
    @State private var hasSSN: Bool?
    @State private var filingStatus: FilingStatus?
    @State private var hourlyRateText = ""
    @State private var workweekStartsOn = 1
    @State private var magiText = ""
    @State private var marginalPercent = 22
    @State private var acceptedDisclaimer = false
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var focusedField: Field?

    private let taxYear = TaxProfile.defaultTaxYear()

    private enum Field: Hashable {
        case rate, magi
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: 3)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .accessibilityLabel("Step \(step + 1) of 3")

                Form {
                    switch step {
                    case 0: eligibilityForm
                    case 1: payForm
                    default: taxForm
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                footer
            }
            .navigationTitle(step == 0 ? AppIdentity.displayName : stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .alert("Couldn't save", isPresented: saveAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case 1: "Pay"
        default: "Taxes"
        }
    }

    private var eligibilityForm: some View {
        Group {
            Section {
                Text("Three questions, then your filing status. This only labels the estimate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Eligibility") {
                YesNoPicker(
                    title: "Hourly and non-exempt?",
                    detail: "Exempt salaried staff generally do not qualify for the overtime deduction.",
                    selection: $isHourly
                )
                YesNoPicker(
                    title: "Paid overtime after 40 hours in a workweek?",
                    detail: "The deduction is the FLSA half-time premium, not daily or double-time pay.",
                    selection: $paidOvertime
                )
                YesNoPicker(
                    title: "Valid Social Security number?",
                    detail: "The deduction requires a valid SSN.",
                    selection: $hasSSN
                )
            }

            Section("Filing status") {
                Picker("Filing status", selection: $filingStatus) {
                    Text("Select").tag(nil as FilingStatus?)
                    ForEach(FilingStatus.allCases, id: \.self) { status in
                        Text(AppFormatting.filingStatusTitle(status)).tag(status as FilingStatus?)
                    }
                }
            }

            if overtimeEstimatesAtZero {
                Section {
                    Text("Under the rules this app uses, the overtime deduction estimates as $0 for this profile. You can still save it. Car-loan estimates are separate.")
                        .font(.subheadline)
                }
            }
        }
    }

    private var payForm: some View {
        Group {
            Section {
                TextField("Straight-time hourly rate", text: $hourlyRateText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .rate)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Base rate")
            } footer: {
                Text("Your primary job. Shift differentials are entered later, on each week. Hours at different employers are not combined.")
            }

            Section {
                Picker("Workweek starts", selection: $workweekStartsOn) {
                    ForEach(1...7, id: \.self) { day in
                        Text(AppFormatting.weekdayName(day)).tag(day)
                    }
                }
            } header: {
                Text("FLSA workweek")
            } footer: {
                Text("A fixed 7-day week. Sunday is day 1. This is not the pay-period start.")
            }
        }
    }

    private var taxForm: some View {
        Group {
            Section {
                LabeledContent("Tax year", value: String(taxYear))
                TextField("Estimated MAGI", text: $magiText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .magi)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Estimated federal bracket", selection: $marginalPercent) {
                    ForEach(AppFormatting.marginalBrackets, id: \.self) { percent in
                        Text("\(percent)%").tag(percent)
                    }
                }
            } header: {
                Text("Estimate")
            } footer: {
                Text("Modified adjusted gross income and the marginal bracket are estimates. They are only used for the phase-out and estimated tax saved.")
            }

            Section {
                Toggle(isOn: $acceptedDisclaimer) {
                    Text(AppCopy.disclaimer)
                }
            } header: {
                Text("Required")
            } footer: {
                Text("Turn this on to save the profile. The same sentence stays in Settings.")
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if step == 0 {
                Text(AppCopy.disclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .disabled(isSaving)
                }
                Spacer()
                Button(step == 2 ? "Save profile" : "Continue") {
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdvance || isSaving)
            }
        }
        .padding()
        .background(.bar)
    }

    private var canAdvance: Bool {
        switch step {
        case 0:
            return isHourly != nil && paidOvertime != nil && hasSSN != nil && filingStatus != nil
        case 1:
            guard let rate = AppFormatting.parseDecimal(hourlyRateText) else { return false }
            return rate > 0
        default:
            guard acceptedDisclaimer, let magi = AppFormatting.parseDecimal(magiText) else { return false }
            return magi >= 0
        }
    }

    private var overtimeEstimatesAtZero: Bool {
        isHourly == false || paidOvertime == false || hasSSN == false || filingStatus == .marriedFilingSeparately
    }

    private var saveAlertPresented: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private func advance() {
        focusedField = nil
        if step < 2 {
            step += 1
        } else {
            save()
        }
    }

    private func save() {
        guard let filingStatus, let hasSSN, let isHourly, let paidOvertime,
              let rate = AppFormatting.parseDecimal(hourlyRateText), rate > 0,
              let magi = AppFormatting.parseDecimal(magiText), magi >= 0,
              acceptedDisclaimer, !isSaving else { return }

        isSaving = true
        let profile = TaxProfile(
            taxYear: taxYear,
            filingStatus: filingStatus,
            estimatedMAGI: magi,
            marginalRate: Decimal(marginalPercent) / 100,
            hasSSN: hasSSN,
            isHourlyNonExempt: isHourly,
            paidOvertimeOver40: paidOvertime,
            acceptedDisclaimer: true
        )
        let employer = Employer(
            name: "Primary job",
            workweekStartsOn: workweekStartsOn,
            defaultRate: rate
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

