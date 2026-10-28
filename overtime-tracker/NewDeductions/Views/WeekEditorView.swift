import OvertimeCore
import SwiftData
import SwiftUI

struct WeekEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let route: WeekRoute
    let employer: Employer
    let taxYear: Int
    let locksDate: Bool

    @State private var startDate = Date()
    @State private var hoursText = ""
    @State private var rateText = ""
    @State private var extrasText = ""
    @State private var note = ""
    @State private var loaded = false
    @State private var message: String?
    @State private var confirmDelete = false
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case hours, rate, extras, note
    }

    private static let quarterHour = Decimal(string: "0.25", locale: Locale(identifier: "en_US_POSIX"))!

    private var calendar: Calendar { .current }

    private var existing: Week? {
        guard case .edit(let id) = route.kind else { return nil }
        return employer.weeks.first { $0.persistentModelID == id }
    }

    private var dateRange: ClosedRange<Date> {
        earliest <= latest ? earliest...latest : earliest...earliest
    }

    private var earliest: Date {
        WorkweekDates.earliestStart(taxYear: taxYear, weekday: employer.workweekStartsOn, calendar: calendar)
    }

    private var latest: Date {
        WorkweekDates.latestStart(taxYear: taxYear, weekday: employer.workweekStartsOn, calendar: calendar)
    }

    private var freeStart: Date {
        WorkweekDates.freeTierWeekStart(
            taxYear: taxYear,
            weekday: employer.workweekStartsOn,
            now: Date(),
            calendar: calendar
        )
    }

    private var draft: WorkWeek? {
        guard let hours = AppFormatting.parseDecimal(hoursText), hours >= 0, hours <= 168,
              let rate = AppFormatting.parseDecimal(rateText), rate >= 0 else { return nil }
        let extras = AppFormatting.parseDecimal(extrasText) ?? 0
        guard extras >= 0 else { return nil }
        return WorkWeek(hoursWorked: hours, hourlyRate: rate, includableExtras: extras)
    }

    var body: some View {
        Form {
            Section {
                DatePicker(
                    "Week start",
                    selection: $startDate,
                    in: dateRange,
                    displayedComponents: .date
                )
                .disabled(locksDate)
            } header: {
                Text("Workweek")
            } footer: {
                Text(locksDate
                     ? "The free estimate includes the current workweek, which starts on \(AppFormatting.weekdayName(employer.workweekStartsOn)). Earlier weeks are locked."
                     : "Starts on \(AppFormatting.weekdayName(employer.workweekStartsOn)). Weeks can go back to the workweek that includes January 1, \(String(taxYear)).")
            }

            Section {
                HStack {
                    TextField("Hours worked", text: $hoursText)
                        .keyboardType(.decimalPad)
                        .focused($focused, equals: .hours)
                    Stepper(
                        "Quarter hour",
                        onIncrement: { adjustHours(by: Self.quarterHour) },
                        onDecrement: { adjustHours(by: -Self.quarterHour) }
                    )
                        .labelsHidden()
                        .accessibilityLabel("Adjust hours by a quarter hour")
                }
                TextField("Base hourly rate", text: $rateText)
                    .keyboardType(.decimalPad)
                    .focused($focused, equals: .rate)
                TextField("Includable extras for the week", text: $extrasText)
                    .keyboardType(.decimalPad)
                    .focused($focused, equals: .extras)
            } header: {
                Text("Pay")
            } footer: {
                Text("Hours can include quarter hours, such as 40.25. Extras are nondiscretionary bonuses or shift differentials for this week, in dollars. Leave extras blank for $0.")
            }

            Section {
                TextField("Note", text: $note, axis: .vertical)
                    .focused($focused, equals: .note)
            }

            if let draft {
                let result = OvertimeCalculator.compute(draft)
                Section {
                    EstimateLine(title: "Regular rate (estimate)", amount: result.regularRate)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Overtime hours (estimate)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(AppFormatting.hours(result.overtimeHours))
                            .font(.title3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    EstimateLine(title: "Qualified premium (estimate)", amount: result.qualifiedPremium,
                                 detail: "0.5 × regular rate × hours over 40. Not the full 1.5× paycheck amount.")
                    Text(AppCopy.estimateFootnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }

            if existing != nil {
                Section {
                    Button("Delete week", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .navigationTitle(existing == nil ? "Add week" : "Edit week")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(draft == nil)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
            }
        }
        .onAppear(perform: load)
        .onChange(of: startDate) { _, newValue in
            guard !locksDate else { return }
            let snapped = clamped(WorkweekDates.startOfWeek(containing: newValue, weekday: employer.workweekStartsOn, calendar: calendar))
            if !calendar.isDate(snapped, inSameDayAs: startDate) {
                startDate = snapped
            }
        }
        .confirmationDialog("Delete this week?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete week", role: .destructive) { deleteWeek() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let existing {
            startDate = clamped(WorkweekDates.startOfWeek(containing: existing.startDate, weekday: employer.workweekStartsOn, calendar: calendar))
            hoursText = AppFormatting.editableDecimal(existing.hoursWorked)
            rateText = AppFormatting.editableDecimal(existing.hourlyRate)
            extrasText = existing.includableExtras == 0 ? "" : AppFormatting.editableDecimal(existing.includableExtras)
            note = existing.note ?? ""
        } else {
            startDate = locksDate ? freeStart : clamped(freeStart)
            rateText = AppFormatting.editableDecimal(employer.defaultRate)
        }
        if locksDate {
            startDate = freeStart
        }
    }

    private func clamped(_ date: Date) -> Date {
        min(max(date, earliest), latest)
    }

    private func adjustHours(by delta: Decimal) {
        let current = AppFormatting.parseDecimal(hoursText) ?? 0
        var next = current + delta
        if next < 0 { next = 0 }
        if next > 168 { next = 168 }
        hoursText = AppFormatting.editableDecimal(next)
    }

    private func save() {
        focused = nil
        message = nil
        if case .edit = route.kind, existing == nil {
            message = "This week is no longer saved."
            return
        }
        guard let draft else {
            message = "Enter hours and a base rate. Hours can be zero."
            return
        }
        let snapped = locksDate ? freeStart : clamped(WorkweekDates.startOfWeek(containing: startDate, weekday: employer.workweekStartsOn, calendar: calendar))
        let duplicate = employer.weeks.contains { other in
            other.persistentModelID != existing?.persistentModelID && calendar.isDate(other.startDate, inSameDayAs: snapped)
        }
        if duplicate {
            message = "A week starting on this date is already logged."
            return
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedNote = trimmedNote.isEmpty ? nil : trimmedNote
        if let existing {
            existing.startDate = snapped
            existing.hoursWorked = draft.hoursWorked
            existing.hourlyRate = draft.hourlyRate
            existing.includableExtras = draft.includableExtras
            existing.note = savedNote
        } else {
            let week = Week(
                startDate: snapped,
                hoursWorked: draft.hoursWorked,
                hourlyRate: draft.hourlyRate,
                includableExtras: draft.includableExtras,
                note: savedNote,
                employer: employer
            )
            modelContext.insert(week)
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }

    private func deleteWeek() {
        guard let existing else { return }
        modelContext.delete(existing)
        try? modelContext.save()
        dismiss()
    }
}
