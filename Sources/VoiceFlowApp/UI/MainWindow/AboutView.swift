import SwiftUI

struct AboutView: View {
    private let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "OpenVoiceText"
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
                        Text(appName)
                            .font(DS.Font.title)
                        Text("about.version \(version) \(build)")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.secondary)
                        #if PROFEATURES
                        Text("about.tagline_pro")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Colors.secondary)
                        #else
                        Text("about.tagline")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Colors.secondary)
                        #endif
                    }
                }
                .padding(.vertical, DS.Spacing.sm)
            }

            Section("about.links") {
                #if PROFEATURES
                Link(destination: URL(string: "https://voicelatte.app/")!) {
                    Label("about.website", systemImage: "globe")
                }
                .foregroundStyle(DS.Colors.espresso)
                #else
                Link(destination: URL(string: "https://github.com/hibachi-inc/OpenVoiceText")!) {
                    Label("about.github", systemImage: "link")
                }
                .foregroundStyle(DS.Colors.espresso)
                #endif

                Link(destination: URL(string: "https://github.com/hibachi-inc/OpenVoiceText/issues")!) {
                    Label("about.bug_report", systemImage: "ladybug")
                }
                .foregroundStyle(DS.Colors.espresso)

                Link(destination: URL(string: "https://x.com/tanakaisworking")!) {
                    Label("about.x_account", systemImage: "at")
                }
                .foregroundStyle(DS.Colors.espresso)

                Link(destination: URL(string: "https://rekinote.app/")!) {
                    Label("about.reki", systemImage: "doc.richtext")
                }
                .foregroundStyle(DS.Colors.espresso)
            }

            #if !PROFEATURES
            Section("about.license") {
                Text("about.license_text")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
            #endif

            Section {
                Text("about.privacy")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(DS.Colors.windowBg)
        .navigationTitle(String(localized: "sidebar.about"))
    }
}
