import OvertimeCore
import SwiftData
import SwiftUI

struct CarLoanTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premium: PremiumStore
    @Query(sort: \Vehicle.vin) private var vehicles: [Vehicle]

    @State private var vinText = ""
    @State private var vinMessage: String?
    @State private var isDecoding = false
    @State private var showPaywall = false
    @FocusState private var vinFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("VIN", text: $vinText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .focused($vinFocused)
                        .accessibilityLabel("VIN")
                    Text("\(VINValidator.normalize(vinText).count) of 17")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        checkVIN()
                    } label: {
                        if isDecoding {
                            ProgressView()
                        } else {
                            Text("Check VIN")
                        }
                    }
                    .disabled(isDecoding)
                    if let vinMessage {
                        Text(vinMessage)
                            .font(.body)
                    }
                } header: {
                    Text("VIN check")
                } footer: {
                    Text("The check digit is verified on this device. A valid VIN is sent to NHTSA so the app can read Plant Country. US final assembly can qualify. Anything else shows Not eligible, or Unknown if the field is blank.")
                }

                if !vehicles.isEmpty {
                    Section("Vehicles") {
                        ForEach(vehicles) { vehicle in
                            vehicleBlock(vehicle)
                        }
                        .onDelete(perform: deleteVehicles)
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
                    Text(AppCopy.estimateFootnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
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
        VStack(alignment: .leading, spacing: 4) {
            Text(vehicle.vin)
                .font(.body.monospaced())
            Text(vehicle.displayTitle)
            Text(AssemblyCopy.line(vehicle.assemblySignal))
                .font(.headline)
            if let country = vehicle.plantCountry {
                Text("Plant country: \(country)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
