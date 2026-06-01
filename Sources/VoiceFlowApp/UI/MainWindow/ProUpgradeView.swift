import SwiftUI

struct ProUpgradeView: View {
    @State private var upgradeManager = ProUpgradeManager.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundStyle(DS.Colors.accent)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("OpenVoiceText Pro")
                            .font(DS.Font.title)
                        if upgradeManager.isPro {
                            Text("Unlocked")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.success)
                        } else {
                            Text("Upgrade to unlock AI refinement and translation")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.secondary)
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.sm)
            }

            if !upgradeManager.isPro {
                Section("Pro Features") {
                    Label("AI-powered text refinement", systemImage: "sparkles")
                    Label("Context-aware formatting (chat, email, code...)", systemImage: "app.dashed")
                    Label("Multi-language translation", systemImage: "globe")
                    Label("Translate with per-language shortcuts", systemImage: "keyboard")
                }

                Section {
                    Button(action: { Task { await upgradeManager.purchase() } }) {
                        HStack {
                            Spacer()
                            if let product = upgradeManager.product {
                                Text("Upgrade for \(product.displayPrice)")
                                    .font(DS.Font.bodyMedium)
                            } else {
                                Text("Loading...")
                                    .font(DS.Font.bodyMedium)
                            }
                            Spacer()
                        }
                    }
                    .disabled(upgradeManager.product == nil)

                    Button("Restore Purchases") {
                        Task { await upgradeManager.restorePurchases() }
                    }
                }

                if case .failed(let message) = upgradeManager.purchaseState {
                    Section {
                        Text(message)
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.error)
                    }
                }
            } else {
                Section {
                    Label("AI Refinement", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.success)
                    Label("Translation", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.success)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pro")
    }
}
