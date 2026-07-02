import SwiftUI

// MARK: - Alert List

struct PriceAlertView: View {
    let currentBTCPrice: Double
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = AlertService.shared
    @State private var showAdd = false
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.06, blue: 0.06).ignoresSafeArea()

                if service.alerts.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(service.alerts) { alert in
                            AlertRow(alert: alert, currentBTCPrice: currentBTCPrice)
                                .listRowBackground(Color.white.opacity(0.05))
                                .listRowSeparatorTint(.white.opacity(0.07))
                        }
                        .onDelete { service.remove(at: $0) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Price Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            if await PushService.shared.enable() { showAdd = true }
                            else { permissionDenied = true }
                        }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddAlertView(currentBTCPrice: currentBTCPrice)
            }
            .alert("Notifications Disabled", isPresented: $permissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications in Settings → TapBTC to receive price alerts.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Alerts Set")
                .font(.title3.bold())
            Text("Tap + to add a price target.\nAlerts fire when BTC crosses your threshold.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Alert Row

private struct AlertRow: View {
    let alert: PriceAlert
    let currentBTCPrice: Double
    @ObservedObject private var service = AlertService.shared
    @State private var showEdit = false

    private var color: Color {
        alert.direction == .above
            ? Color(red: 0.19, green: 0.82, blue: 0.35)
            : Color(red: 1.00, green: 0.27, blue: 0.23)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Tappable area: icon + labels + chevron
            Button { showEdit = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(color.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: alert.direction == .above ? "arrow.up" : "arrow.down")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(BitcoinPrice(usd: alert.targetPrice, timestamp: .now).formatted)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(alert.isEnabled ? .white : .secondary)
                            Text(alert.direction == .above ? "or higher" : "or lower")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        HStack(spacing: 6) {
                            if !alert.label.isEmpty {
                                Text(alert.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if alert.isRepeating {
                                Label("Repeat", systemImage: "repeat")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                            }
                            if let fired = alert.lastFiredAt {
                                Text("Fired \(fired, style: .relative) ago")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { alert.isEnabled },
                set: { _ in service.toggle(id: alert.id) }
            ))
            .labelsHidden()
            .tint(.orange)
        }
        .padding(.vertical, 4)
        .opacity(alert.isEnabled ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: alert.isEnabled)
        .sheet(isPresented: $showEdit) {
            AddAlertView(currentBTCPrice: currentBTCPrice, editingAlert: alert)
        }
    }
}

// MARK: - Add / Edit Alert Sheet

struct AddAlertView: View {
    let currentBTCPrice: Double
    var editingAlert: PriceAlert? = nil

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = AlertService.shared

    @State private var direction: PriceAlert.Direction = .above
    @State private var targetText = ""
    @State private var labelText = ""
    @State private var isRepeating = false
    @FocusState private var priceFocused: Bool

    private var isEditing: Bool { editingAlert != nil }

    private var targetPrice: Double? {
        Double(targetText.replacingOccurrences(of: ",", with: ""))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.06, blue: 0.06).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        // Direction
                        field("Direction") {
                            HStack(spacing: 0) {
                                dirButton("Above  ↑", value: .above)
                                dirButton("Below  ↓", value: .below)
                            }
                            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Target price
                        field("Target Price") {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("$")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                TextField("0", text: $targetText)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .keyboardType(.numberPad)
                                    .focused($priceFocused)
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(priceFocused ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)))
                            .animation(.easeInOut(duration: 0.15), value: priceFocused)
                        }

                        // Quick suggestions
                        if currentBTCPrice > 0 {
                            field("Quick Add") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(suggestions, id: \.label) { s in
                                            Button {
                                                targetText = "\(Int(s.price))"
                                                priceFocused = false
                                            } label: {
                                                VStack(spacing: 2) {
                                                    Text(s.label)
                                                        .font(.system(size: 13, weight: .semibold))
                                                    Text("$\(Int(s.price).formatted())")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding(.horizontal, 14).padding(.vertical, 9)
                                                .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)))
                                                .foregroundStyle(.white)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Label
                        field("Label  (optional)") {
                            TextField("e.g. Take profit, Buy the dip", text: $labelText)
                                .font(.system(size: 16))
                                .padding(.horizontal, 16).padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
                                .foregroundStyle(.white)
                        }

                        // Repeat
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Repeat")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Re-arm after each trigger · 1-hour cooldown")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $isRepeating).labelsHidden().tint(.orange)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
                    }
                    .padding(20)
                }
            }
            // Pinned to the bottom of the sheet; slides up above the keyboard
            // so it's always tappable while typing.
            .safeAreaInset(edge: .bottom) {
                Button {
                    guard let price = targetPrice else { return }
                    if isEditing, var updated = editingAlert {
                        updated.direction = direction
                        updated.targetPrice = price
                        updated.label = labelText
                        updated.isRepeating = isRepeating
                        service.update(updated)
                    } else {
                        service.add(PriceAlert(label: labelText, targetPrice: price,
                                               direction: direction, isRepeating: isRepeating))
                    }
                    dismiss()
                } label: {
                    Text(isEditing ? "Save Changes" : "Add Alert")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(targetPrice == nil ? Color.orange.opacity(0.4) : .orange))
                        .foregroundStyle(.black)
                }
                .disabled(targetPrice == nil)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
            .navigationTitle(isEditing ? "Edit Alert" : "New Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let a = editingAlert {
                    direction = a.direction
                    targetText = "\(Int(a.targetPrice))"
                    labelText = a.label
                    isRepeating = a.isRepeating
                } else {
                    priceFocused = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            content()
        }
    }

    @ViewBuilder
    private func dirButton(_ title: String, value: PriceAlert.Direction) -> some View {
        Button { direction = value } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(direction == value ? Color.orange : Color.clear)
                .foregroundStyle(direction == value ? .black : .secondary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.15), value: direction)
    }

    private var suggestions: [(label: String, price: Double)] {
        let p = currentBTCPrice
        return [
            ("+5%",  p * 1.05), ("+10%", p * 1.10), ("+20%", p * 1.20),
            ("-5%",  p * 0.95), ("-10%", p * 0.90), ("-20%", p * 0.80),
        ].map { (label: $0.0, price: Double(Int($0.1 / 1000) * 1000)) }
    }
}
