import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

    var body: some View {
        Form {
            Section {
                HStack(spacing: DS.Spacing.lg) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("OpenVoiceText")
                            .font(DS.Font.title)
                        Text("about.version \(version) \(build)")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.secondary)
                        Text("about.tagline")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }
                .padding(.vertical, DS.Spacing.sm)
            }

            Section("about.links") {
                Link(destination: URL(string: "https://github.com/hibachi-inc/OpenVoiceText")!) {
                    Label("about.github", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/hibachi-inc/OpenVoiceText/issues")!) {
                    Label("about.bug_report", systemImage: "ladybug")
                }

                Link(destination: URL(string: "https://x.com/tanakaisworking")!) {
                    Label("about.x_account", systemImage: "at")
                }

                Link(destination: URL(string: "https://rekinote.app/")!) {
                    Label("about.reki", systemImage: "doc.richtext")
                }
            }

            Section {
                Text("about.privacy")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "sidebar.about"))
    }
}
