import OvertimeCore
import SwiftData
import SwiftUI

struct CarLoanTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premium: PremiumStore
    @Query(sort: \Vehicle.vin) private var vehicles: [Vehicle]
    @Query private var profiles: [TaxProfile]

    @State private var vinText = ""
    @State private var vinMessage: String?
    @State private var isDecoding = false
    @State private var showPaywall = false
    @FocusState private var vinFocused: Bool

    private var profile: TaxProfile? {
        profiles.first(where: \.acceptedDisclaimer) ?? profiles.first
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Theme.emerald, Theme.gold)
                                .frame(width: 52, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Theme.backgroundElevated)
                                )
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile?.wantsCarLoan == true ? "Your new car" : "Car loan interest")
                                    .font(Theme.rounded(.title3, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                                Text(carIntro)
                                    .font(Theme.rounded(.subheadline))
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        TextField("VIN", text: $vinText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                            .focused($vinFocused)
                            .accessibilityLabel("VIN")
                        Text("\(VINValidator.normalize(vinText).count) of 17")
                            .font(Theme.rounded(.caption))
                            .foregroundStyle(Theme.textSecondary)
                        Button {
                            checkVIN()
                        } label: {
                            if isDecoding {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            } else {
                                Text("Check VIN")
                                    .font(Theme.rounded(.headline, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isDecoding)
                        if let vinMessage {
                            Text(vinMessage)
                                .font(Theme.rounded(.body))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    ThemeSectionHeader("VIN check")
                } footer: {
                    Text("The check digit is verified on this device. A valid VIN is sent to NHTSA so the app can read Plant Country. US final assembly can qualify. Anything else shows Not eligible, or Unknown if the field is blank.")
                }

                if !vehicles.isEmpty {
                    Section {
                        ForEach(vehicles) { vehicle in
                            vehicleBlock(vehicle)
                        }
                        .onDelete(perform: deleteVehicles)
                    } header: {
                        ThemeSectionHeader("Your cars")
                    }
                }

                if !premium.isPremium {
                    Section {
                        PremiumLockedSection(
                            message: "The eligibility checklist, the loan, Form 1098-VLI, and the deduction estimate are locked. The VIN check stays free."
                        )
                    }
                }

                Section {
                    EstimateFootnote()
                }
            }
            .themeGroupedList()
            .navigationTitle("Car Loan")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { vinFocused = false }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(premium)
            }
        }
    }

    private var carIntro: String {
        if profile?.wantsCarLoan == true {
            return "You mentioned a new car. A free VIN check is the first step. The loan details come after that."
        }
        return "Have a car from 2025 or later? Check the VIN and we'll estimate the interest deduction."
    }

    @ViewBuilder
    private func vehicleBlock(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if premium.isPremium {
                NavigationLink {
                    VehicleDetailView(vehicle: vehicle)
                } label: {
                    vehicleSummary(vehicle)
                }
            } else {
                vehicleSummary(vehicle)
            }
            if vehicle.assemblySignal == .unknown || vehicle.assemblySignal == .stickerConfirmedUS {
                Toggle(
                    "The door-jamb label shows US final assembly",
                    isOn: Binding(
                        get: { vehicle.stickerConfirmedUS == true },
                        set: { confirmed in
                            vehicle.stickerConfirmedUS = confirmed
                            vehicle.assemblySignal = confirmed ? .stickerConfirmedUS : .unknown
                            try? modelContext.save()
                        }
                    )
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func vehicleSummary(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vehicle.displayTitle)
                .font(Theme.rounded(.headline, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(vehicle.vin)
                .font(.body.monospaced())
                .foregroundStyle(Theme.textSecondary)
            Text(AssemblyCopy.line(vehicle.assemblySignal))
                .font(Theme.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(assemblyColor(vehicle.assemblySignal).opacity(0.18))
                )
            if let country = vehicle.plantCountry {
                Text("Plant country: \(country)")
                    .font(Theme.rounded(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func assemblyColor(_ signal: AssemblySignal) -> Color {
        switch signal {
        case .usPlant, .stickerConfirmedUS:
            return Theme.emerald
        case .unknown:
            return Theme.gold
        case .nonUSPlant:
            return Theme.textSecondary
        }
    }

    private func checkVIN() {
        vinFocused = false
        let status = VINValidator.status(vinText)
        switch status {
        case .valid:
            vinMessage = nil
            isDecoding = true
            let entered = vinText
            Task {
                defer { isDecoding = false }
                do {
                    let decoded = try await NHTSAClient.decode(vin: entered)
                    upsert(vin: entered, decoded: decoded)
                    vinMessage = AssemblyCopy.line(assemblyAfterSave(decoded: decoded, vin: entered))
                } catch {
                    upsertUnknown(vin: entered)
                    vinMessage = "Unknown, check the door-jamb label."
                }
            }
        case .wrongLength(let count):
            vinMessage = "A VIN is 17 characters. This one has \(count)."
        case .illegalCharacter(let character):
            vinMessage = "“\(character)” is not allowed in a VIN. I, O, and Q never are."
        case .badCheckDigit(let expected):
            vinMessage = "The check digit does not match. Expected \(expected)."
        }
    }

    private func assemblyAfterSave(decoded: VPICDecoder.Decoded, vin: String) -> AssemblySignal {
        let normalized = VINValidator.normalize(vin)
        return vehicles.first { VINValidator.normalize($0.vin) == normalized }?.assemblySignal ?? decoded.assembly
    }

    private func upsert(vin: String, decoded: VPICDecoder.Decoded) {
        let vehicle = findOrCreate(vin: vin)
        vehicle.make = decoded.make
        vehicle.model = decoded.model
        vehicle.modelYear = decoded.modelYear
        vehicle.plantCountry = decoded.plantCountry
        vehicle.gvwrClass = decoded.gvwrText
        vehicle.gvwrPounds = decoded.gvwrPounds
        vehicle.vehicleType = decoded.vehicleType
        vehicle.decodedAt = Date()
        if decoded.assembly == .unknown, vehicle.stickerConfirmedUS == true {
            vehicle.assemblySignal = .stickerConfirmedUS
        } else {
            vehicle.assemblySignal = decoded.assembly
            if decoded.assembly != .unknown {
                vehicle.stickerConfirmedUS = nil
            }
        }
        try? modelContext.save()
    }

    private func upsertUnknown(vin: String) {
        let vehicle = findOrCreate(vin: vin)
        vehicle.decodedAt = Date()
        if vehicle.stickerConfirmedUS == true {
            vehicle.assemblySignal = .stickerConfirmedUS
        } else {
            vehicle.assemblySignal = .unknown
        }
        try? modelContext.save()
    }

    private func findOrCreate(vin: String) -> Vehicle {
        let normalized = VINValidator.normalize(vin)
        if let existing = vehicles.first(where: { VINValidator.normalize($0.vin) == normalized }) {
            existing.vin = normalized
            return existing
        }
        let vehicle = Vehicle(vin: normalized)
        modelContext.insert(vehicle)
        return vehicle
    }

    private func deleteVehicles(at offsets: IndexSet) {
        let snapshot = vehicles
        for index in offsets {
            modelContext.delete(snapshot[index])
        }
        try? modelContext.save()
    }
}
