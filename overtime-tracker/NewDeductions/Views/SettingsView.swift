import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxProfile.taxYear) private var profiles: [TaxProfile]
    @Query(sort: \Employer.name) private var employers: [Employer]

    @State private var confirmReset = false
    @State private var resetError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(AppCopy.disclaimer)
                        .font(.body)
                } header: {
                    Text("Disclaimer")
                } footer: {
                    Text("Accepted during setup. The overtime, car-loan, and summary screens repeat it.")
                }

                if let profile = profiles.first(where: \.acceptedDisclaimer) ?? profiles.first {
                    Section("Tax profile") {
                        LabeledContent("Tax year", value: String(profile.taxYear))
                        LabeledContent("Filing status", value: AppFormatting.filingStatusTitle(profile.filingStatus))
                        LabeledContent("Estimated MAGI", value: AppFormatting.currency(profile.estimatedMAGI))
                        LabeledContent("Estimated bracket", value: AppFormatting.percent(profile.marginalRate))
                        LabeledContent("Valid SSN", value: profile.hasSSN ? "Yes" : "No")
                        LabeledContent("Hourly, non-exempt", value: profile.isHourlyNonExempt ? "Yes" : "No")
                        LabeledContent("Paid OT over 40", value: profile.paidOvertimeOver40 ? "Yes" : "No")
                    }
                }

                if !employers.isEmpty {
                    Section {
                        ForEach(employers) { employer in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(employer.name)
                                Text("\(AppFormatting.currency(employer.defaultRate)) / hour")
                                    .foregroundStyle(.secondary)
                                Text("Workweek starts \(AppFormatting.weekdayName(employer.workweekStartsOn))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Employer")
                    } footer: {
                        Text("Overtime is calculated per employer. This version keeps the primary job from setup.")
                    }
                }

                Section {
                    ForEach(TaxSources.overtime) { source in
                        sourceLink(source)
                    }
                } header: {
                    Text("Overtime sources")
                }

                Section {
                    ForEach(TaxSources.carLoan) { source in
                        sourceLink(source)
                    }
                } header: {
                    Text("Car loan sources")
                } footer: {
                    Text("These open in Safari when you tap them. The app does not download them.")
                }

                Section {
                    LabeledContent("Version", value: versionText)
                    Text("Estimates stay on this device. iCloud sync is off.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(AppIdentity.displayName)
                }

                Section {
                    Button("Reset onboarding", role: .destructive) {
                        confirmReset = true
                    }
                } footer: {
                    Text("Deletes the tax profile and employer stored on this device.")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Reset onboarding?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Delete profile", role: .destructive) { resetStore() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes the tax profile and employer stored on this device.")
            }
            .alert("Couldn't reset", isPresented: resetAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resetError ?? "")
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
