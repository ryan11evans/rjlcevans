import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pro = ProService.shared
    @State private var purchasing = false
    @State private var showThanks = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.06, blue: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(.orange.opacity(0.15))
                                        .frame(width: 84, height: 84)
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundStyle(.orange)
                                }
                                Text("TapBTC Pro")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                Text("One-time purchase. Yours forever.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 24)

                            // Features
                            VStack(spacing: 0) {
                                feature(icon: "bell.badge.fill",
                                        title: "Unlimited price alerts",
                                        subtitle: "Free includes \(ProService.freeAlertLimit) — Pro removes the cap")
                                Divider().padding(.leading, 56)
                                feature(icon: "arrow.up.heart.fill",
                                        title: "Support development",
                                        subtitle: "Keeps the alert server running — no ads, no accounts, ever")
                                Divider().padding(.leading, 56)
                                feature(icon: "sparkles",
                                        title: "All future Pro features",
                                        subtitle: "Every Pro feature we add is included")
                            }
                            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.05)))
                            .padding(.horizontal, 20)
                        }
                    }

                    // Purchase area pinned at bottom
                    VStack(spacing: 12) {
                        Button {
                            purchasing = true
                            Task {
                                let ok = await pro.purchase()
                                purchasing = false
                                if ok { showThanks = true }
                            }
                        } label: {
                            Group {
                                if purchasing {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Unlock Pro · \(pro.priceText)")
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.orange))
                            .foregroundStyle(.black)
                        }
                        .disabled(purchasing)

                        Button("Restore Purchases") {
                            Task {
                                await pro.restore()
                                if pro.isPro { showThanks = true }
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("You're Pro! ⚡️", isPresented: $showThanks) {
                Button("Let's go") { dismiss() }
            } message: {
                Text("Thanks for supporting TapBTC. Unlimited alerts are unlocked.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func feature(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
