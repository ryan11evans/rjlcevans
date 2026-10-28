import SwiftData

/// Local SwiftData store. iCloud is off for v1.0 (`cloudKitDatabase: .none`); there is no CloudKit entitlement.
enum AppModelContainer {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            Employer.self,
            Week.self,
            Shift.self,
            TaxProfile.self,
            Vehicle.self,
            VehicleLoan.self,
        ])
        let configuration = ModelConfiguration(
            "NewDeductions",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not open the local store: \(error)")
        }
    }
}
