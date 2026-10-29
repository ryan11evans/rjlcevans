import OvertimeCore
import SwiftUI
import UIKit

struct W4FlowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var premium: PremiumStore

    let taxYear: Int
    let filingStatus: FilingStatus
    let overtimeDeduction: Decimal
    let carDeduction: Decimal
    let line4b: Decimal

    @State private var step = 0
    @State private var copied = false

    private let stepCount = 6

    var body: some View {
        Group {
            if premium.isPremium {
                flow
            } else {
                List {
                    Section {
                        PremiumLockedSection(message: "The W-4 helper is part of Pro.")
                    }
                }
            }
        }
        .navigationTitle("Update my W-4")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var flow: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: Double(stepCount))
                .tint(Theme.emerald)
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityLabel("Step \(step + 1) of \(stepCount)")

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stepContent
                    Text(AppCopy.estimateFootnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            HStack {
                if step > 0 {
                    Button("Back") { move(to: step - 1) }
                }
                Spacer()
                if step < stepCount - 1 {
                    Button("Continue") { move(to: step + 1) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.bar)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: explainStep
        case 1: amountStep
        case 2: genericStep
        case 3: adpStep
        case 4: otherPayrollStep
        default: anytimeStep
        }
    }

    private var explainStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Line 4(b) is Deductions")
                .font(.title2.weight(.bold))
            SoftCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Form W-4, Step 4(b), is labeled Deductions. The amount you enter there can lower federal income tax withheld from each paycheck.")
                    Text("This estimate is the projected qualified overtime deduction, after the cap and phase-out, plus car-loan interest if you have a qualifying loan. It is not a filled-out W-4, and it is not a full withholding calculation.")
                    Text("Tax year \(String(taxYear)), \(AppFormatting.filingStatusTitle(filingStatus)). Estimate only, not tax advice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var amountStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter this on line 4(b)")
                .font(.title2.weight(.bold))
            VStack(alignment: .leading, spacing: 6) {
                Text("Estimated deduction")
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
                Text(AppFormatting.currency(line4b))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(AppFormatting.plainMoney(line4b))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.heroGradient))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Estimated line 4(b) amount \(AppFormatting.currency(line4b))")

            Button {
                UIPasteboard.general.string = AppFormatting.plainMoney(line4b)
                copied = true
                Haptics.success()
            } label: {
                Label(copied ? "Copied" : "Copy amount", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Copies the number to type on line 4(b)")

            SoftCard {
                VStack(alignment: .leading, spacing: 8) {
                    labeled("Qualified overtime deduction (estimate)", overtimeDeduction)
                    labeled(
                        carDeduction > 0 ? "Car-loan interest deduction (estimate)" : "Car-loan interest",
                        carDeduction
                    )
                    if carDeduction == 0 {
                        Text("No car-loan interest is included. Add a qualifying loan on the Car Loan tab if you have one.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("Each piece is already after its own cap and phase-out. The total is the estimate to type on line 4(b).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var genericStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send it to payroll")
                .font(.title2.weight(.bold))
            amountReminder
            SoftCard {
                VStack(alignment: .leading, spacing: 10) {
                    stepLine(1, "Ask HR or payroll for the federal Form W-4, or open withholding in your payroll account.")
                    stepLine(2, "Keep the filing status that matches how you file.")
                    stepLine(3, "On Step 4(b), Deductions, enter \(AppFormatting.plainMoney(line4b)).")
                    stepLine(4, "Sign and return it the way your employer accepts a W-4.")
                    Text("Menus differ by employer. The next steps are best-effort paths for a few common systems.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var adpStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADP")
                .font(.title2.weight(.bold))
            amountReminder
            SoftCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("In ADP, the path is often:")
                        .font(.headline)
                    Text("Myself > Pay > Tax Withholding > Federal > edit W-4, Step 4(b)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.emerald)
                    Text("Enter \(AppFormatting.plainMoney(line4b)) on Step 4(b). Menus vary by employer. If you do not see that path, use the generic steps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var otherPayrollStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paychex, Gusto, Workday")
                .font(.title2.weight(.bold))
            Text("Best-effort. Your screens may use different names. Look for federal withholding or Form W-4, then Step 4(b).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            payrollCard(
                name: "Paychex",
                text: "Look for Tax Withholding or Form W-4 under pay or your profile, then the federal form, Step 4(b)."
            )
            payrollCard(
                name: "Gusto",
                text: "Employees often open Pay or Tax forms and edit federal withholding, then Step 4(b)."
            )
            payrollCard(
                name: "Workday",
                text: "Search for withholding elections or Tax Elections, then the federal W-4, Step 4(b)."
            )
        }
    }

    private var anytimeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You can update it any time")
                .font(.title2.weight(.bold))
            SoftCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A W-4 can be replaced whenever your estimate changes. Come back in January and check the number again for the new tax year.")
                    Text("A new W-4 changes withholding on paychecks after your employer processes it. It does not recalculate paychecks already paid.")
                    Text("This is an estimate of line 4(b), not tax advice, and not a complete Form W-4.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            amountReminder
        }
    }

    private var amountReminder: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("Line 4(b) estimate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(AppFormatting.currency(line4b))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.emerald)
            }
        }
    }

    private func payrollCard(name: String, text: String) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepLine(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.emerald))
            Text(text)
                .font(.body)
        }
    }

    private func labeled(_ title: String, _ amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(AppFormatting.currency(amount))
                .font(.title3.weight(.semibold))
        }
    }

    private func move(to newStep: Int) {
        Haptics.select()
        if reduceMotion {
            step = newStep
        } else {
            withAnimation(.snappy) { step = newStep }
        }
    }
}
