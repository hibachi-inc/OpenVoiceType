import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

    var body: some View {
        Form {
            Section {
                HStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "mic.badge.xmark")
                        .font(.system(size: 40))
                        .foregroundStyle(DS.Colors.accent)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("OpenVoiceText")
                            .font(DS.Font.title)
                        Text("Version \(version) (\(build))")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.secondary)
                        Text("Context-aware voice input for macOS")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }
                .padding(.vertical, DS.Spacing.sm)
            }

            Section("Links") {
                Link(destination: URL(string: "https://github.com/hibachi-inc/OpenVoiceText")!) {
                    Label("GitHub Repository", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/hibachi-inc/OpenVoiceText/issues")!) {
                    Label("Report a Bug", systemImage: "ladybug")
                }

                Link(destination: URL(string: "https://rekinote.app/")!) {
                    Label("Reki note — by the same team", systemImage: "doc.richtext")
                }
            }

            Section("License") {
                Text("MIT License — Hibachi Inc.")
                    .font(DS.Font.body)
                Text("100% local processing. No audio or text data ever leaves your Mac.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
    }
}
