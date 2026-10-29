import OvertimeCore
import SwiftData
import SwiftUI

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.vin) private var vehicles: [Vehicle]
    @Query private var profiles: [TaxProfile]

    var vehicle: Vehicle

    @State private var lender = ""
    @State private var principalText = ""
    @State private var aprText = ""
    @State private var termMonths = 60
    @State private var origination = Date()
    @State private var firstPayment = Date()
    @State private var isNew: Bool?
    @State private var personalUse: Bool?
    @State private var firstLien: Bool?
    @State private var isLease = false
    @State private var salvage = false
    @State private var relatedParty = false
    @State private var isRefinance = false
    @State private var gvwrUnder: Bool?
    @State private var actualText = ""
    @State private var loaded = false
    @State private var message: String?
    @State private var confirmDelete = false
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case lender, principal, apr, actual
    }

    private var calendar: Calendar { .current }

    private var profile: TaxProfile? {
        profiles.first(where: \.acceptedDisclaimer) ?? profiles.first
    }

    private var dateRange: ClosedRange<Date> {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? Date()
        let end = calendar.date(from: DateComponents(year: 2028, month: 12, day: 31)) ?? Date()
        return start...end
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SoftCard {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("VIN", value: vehicle.vin)
                        LabeledContent("Vehicle", value: vehicle.displayTitle)
                        LabeledContent("Final assembly", value: AssemblyCopy.line(vehicle.assemblySignal))
                        if let country = vehicle.plantCountry {
                            LabeledContent("Plant country", value: country)
                        }
                        if let gvwr = vehicle.gvwrClass {
                            LabeledContent("GVWR", value: gvwr)
                        }
                    }
                    .font(Theme.rounded(.body))
                }

                checklist
                loanFields

                if let profile {
                    results(profile: profile)
                }

                if let message {
                    Text(message)
                        .font(Theme.rounded(.subheadline))
                        .foregroundStyle(.red)
                }

                ThemeButton(title: "Save loan", enabled: true) {
                    save()
                }

                Button("Delete vehicle", role: .destructive) { confirmDelete = true }
                    .font(Theme.rounded(.headline, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .themeScreen()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(vehicle.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
            }
        }
        .onAppear(perform: load)
        .confirmationDialog("Delete this vehicle and its loan?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete vehicle", role: .destructive, action: deleteVehicle)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var checklist: some View {
        SoftCard {
        VStack(alignment: .leading, spacing: 12) {
            ThemeSectionHeader("Eligibility")
            YesNoPicker(
                title: "New vehicle?",
                detail: "Original use has to start with you.",
                selection: $isNew
            )
            YesNoPicker(
                title: "First lien?",
                detail: "The loan is secured by a first lien on the vehicle.",
                selection: $firstLien
            )
            YesNoPicker(
                title: "More than 50% personal use?",
                detail: "Expected personal use when the loan was taken.",
                selection: $personalUse
            )
            Toggle("Salvage, scrap, or parts title", isOn: $salvage)
            Toggle("Lender is a related party", isOn: $relatedParty)
            Toggle("This is a lease", isOn: $isLease)
            Toggle("This is a refinance", isOn: $isRefinance)
            if vehicle.gvwrPounds == nil {
                YesNoPicker(
                    title: "GVWR under 14,000 lb?",
                    detail: "NHTSA did not give a range that sits entirely under or over the limit.",
                    selection: $gvwrUnder
                )
            }
            Text("A refinance is not treated as disqualifying in this estimate. Confirm the dates against the IRS instructions. The loan must be originated after December 31, 2024. Estimate only, not tax advice.")
                .font(Theme.rounded(.footnote))
                .foregroundStyle(Theme.textSecondary)
        }
        }
    }

    private var loanFields: some View {
        SoftCard {
        VStack(alignment: .leading, spacing: 12) {
            ThemeSectionHeader("Loan")
            TextField("Lender", text: $lender)
                .focused($focused, equals: .lender)
            TextField("Loan amount", text: $principalText)
                .keyboardType(.decimalPad)
                .focused($focused, equals: .principal)
            TextField("APR percent", text: $aprText)
                .keyboardType(.decimalPad)
                .focused($focused, equals: .apr)
            Stepper(value: $termMonths, in: 1...120) {
                Text("Term: \(termMonths) months")
            }
            DatePicker("Loan start", selection: $origination, in: dateRange, displayedComponents: .date)
            DatePicker("First payment", selection: $firstPayment, in: dateRange, displayedComponents: .date)
            TextField("Form 1098-VLI interest", text: $actualText)
                .keyboardType(.decimalPad)
                .focused($focused, equals: .actual)
            Text("Form 1098-VLI interest, when you enter it, replaces the projected interest for this tax year. Leave it blank to use the amortization estimate.")
                .font(Theme.rounded(.footnote))
                .foregroundStyle(Theme.textSecondary)
        }
        }
    }

    @ViewBuilder
    private func results(profile: TaxProfile) -> some View {
        let facts = draftFacts
        let verdict = CarLoanInterestCalculator.verdict(facts)
        SoftCard {
        VStack(alignment: .leading, spacing: 10) {
            ThemeSectionHeader("Estimate")
            Text(CarLoanMath.verdictTitle(verdict))
                .font(.headline)
            if verdict != .eligible {
                ForEach(CarLoanMath.reasons(for: facts), id: \.self) { reason in
                    Text(reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let preview = draftPreview(taxYear: profile.taxYear) {
                EstimateLine(title: "Estimated monthly payment", amount: preview.payment)
                EstimateLine(title: "Projected \(profile.taxYear) interest (estimate)", amount: preview.projected)
                EstimateLine(
                    title: preview.usedActual
                        ? "Interest used, Form 1098-VLI"
                        : "Interest used (estimate)",
                    amount: preview.used,
                    detail: preview.usedActual
                        ? "The form amount replaces the projection for this tax year."
                        : "Amortization of this loan. The $10,000 cap is applied to the combined interest on the Summary tab."
                )
            }
            let deduction = combinedDeduction(profile: profile, verdict: verdict)
            EstimateLine(
                title: "Estimated car-loan deduction",
                amount: deduction,
                detail: "Cap of $10,000, then $200 per $1,000 of MAGI over the threshold, partial thousands rounded up. Only eligible loans are included."
            )
            EstimateLine(
                title: "Estimated federal tax saved",
                amount: FederalBracket.estimate(
                    magi: profile.estimatedMAGI,
                    filingStatus: profile.filingStatus,
                    schedule1ADeductions: deduction
                ).taxSaved,
                detail: "Tax before this deduction minus tax after it. 2026 brackets and the standard deduction. Estimate."
            )
            EstimateFootnote()
        }
        }
    }

    private var draftFacts: VehicleLoanFacts {
        VehicleLoanFacts(
            originationDate: origination,
            isNew: isNew,
            personalUse: personalUse,
            firstLien: firstLien,
            isLease: isLease,
            salvageOrScrap: salvage,
            relatedPartyLender: relatedParty,
            vehicleType: vehicle.vehicleType,
            gvwrPounds: CarLoanMath.resolvedGVWR(pounds: vehicle.gvwrPounds, confirmedUnderLimit: gvwrUnder),
            assembly: vehicle.assemblySignal
        )
    }

    private struct Preview {
        var payment: Decimal
        var projected: Decimal
        var used: Decimal
        var usedActual: Bool
    }

    private func draftPreview(taxYear: Int) -> Preview? {
        guard let principal = AppFormatting.parseDecimal(principalText), principal > 0,
              let apr = AppFormatting.parseDecimal(aprText), apr >= 0, termMonths > 0,
              let projected = CarLoanMath.projectedInterest(
                principal: principal,
                aprPercent: apr,
                termMonths: termMonths,
                firstPayment: firstPayment,
                taxYear: taxYear,
                calendar: calendar
              ) else { return nil }
        let payment = CarLoanInterestCalculator.monthlyPayment(principal: principal, aprPercent: apr, months: termMonths)
        if actualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Preview(payment: payment, projected: projected, used: projected, usedActual: false)
        }
        guard let actual = AppFormatting.parseDecimal(actualText), actual >= 0 else { return nil }
        return Preview(payment: payment, projected: projected, used: actual, usedActual: true)
    }

    /// Return-level deduction: other saved eligible loans, plus this draft when it is eligible.
    private func combinedDeduction(profile: TaxProfile, verdict: EligibilityVerdict) -> Decimal {
        var amounts: [Decimal] = []
        for other in vehicles where other.persistentModelID != vehicle.persistentModelID {
            let line = CarLoanMath.qualifying(vehicles: [other], taxYear: profile.taxYear, calendar: calendar).first
            if line?.included == true {
                amounts.append(line?.used ?? 0)
            }
        }
        if verdict == .eligible, let preview = draftPreview(taxYear: profile.taxYear) {
            amounts.append(preview.used)
        }
        return CarLoanInterestCalculator.deduction(
            loanInterest: amounts,
            magi: profile.estimatedMAGI,
            status: profile.filingStatus,
            taxYear: profile.taxYear
        )
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        isNew = vehicle.isNew
        gvwrUnder = vehicle.userConfirmedGVWRUnderLimit
        if let loan = vehicle.primaryLoan {
            lender = loan.lender == "Lender" ? "" : loan.lender
            principalText = AppFormatting.editableDecimal(loan.principal)
            aprText = AppFormatting.editableDecimal(loan.aprPercent)
            termMonths = min(max(loan.termMonths, 1), 120)
            origination = min(max(loan.originationDate, dateRange.lowerBound), dateRange.upperBound)
            firstPayment = min(max(loan.firstPaymentDate, dateRange.lowerBound), dateRange.upperBound)
            personalUse = loan.personalUse
            firstLien = loan.firstLien
            isLease = loan.isLease
            salvage = loan.salvageOrScrap ?? false
            relatedParty = loan.relatedPartyLender ?? false
            isRefinance = loan.isRefinance
            if let profile, let actual = loan.actualInterest[profile.taxYear] {
                actualText = AppFormatting.editableDecimal(actual)
            }
        } else {
            let today = min(max(Date(), dateRange.lowerBound), dateRange.upperBound)
            origination = today
            firstPayment = min(calendar.date(byAdding: .month, value: 1, to: today) ?? today, dateRange.upperBound)
        }
    }

    private func save() {
        focused = nil
        message = nil
        guard let profile else {
            message = "The tax profile is missing."
            return
        }
        guard let principal = AppFormatting.parseDecimal(principalText), principal > 0 else {
            message = "Enter the loan amount."
            return
        }
        guard let apr = AppFormatting.parseDecimal(aprText), apr >= 0 else {
            message = "Enter the APR as a percent, such as 6 or 6.5."
            return
        }
        let trimmedActual = actualText.trimmingCharacters(in: .whitespacesAndNewlines)
        let actual: Decimal?
        if trimmedActual.isEmpty {
            actual = nil
        } else if let parsed = AppFormatting.parseDecimal(trimmedActual), parsed >= 0 {
            actual = parsed
        } else {
            message = "Enter the Form 1098-VLI interest as a number, or leave it blank."
            return
        }

        vehicle.isNew = isNew
        vehicle.userConfirmedGVWRUnderLimit = vehicle.gvwrPounds == nil ? gvwrUnder : vehicle.userConfirmedGVWRUnderLimit
        let loan: VehicleLoan
        if let existing = vehicle.primaryLoan {
            loan = existing
        } else {
            loan = VehicleLoan(
                lender: "",
                originationDate: origination,
                aprPercent: apr,
                principal: principal,
                termMonths: termMonths,
                firstPaymentDate: firstPayment,
                vehicle: vehicle
            )
            modelContext.insert(loan)
        }
        loan.lender = lender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Lender" : lender
        loan.originationDate = origination
        loan.aprPercent = apr
        loan.principal = principal
        loan.termMonths = termMonths
        loan.firstPaymentDate = firstPayment
        loan.personalUse = personalUse
        loan.firstLien = firstLien
        loan.isLease = isLease
        loan.isRefinance = isRefinance
        loan.salvageOrScrap = salvage
        loan.relatedPartyLender = relatedParty
        loan.setActualInterest(actual, for: profile.taxYear)
        do {
            try modelContext.save()
            message = nil
            Haptics.success()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }

    private func deleteVehicle() {
        modelContext.delete(vehicle)
        try? modelContext.save()
        dismiss()
    }
}
