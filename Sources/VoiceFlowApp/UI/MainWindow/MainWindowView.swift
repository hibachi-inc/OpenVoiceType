import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case general = "General"
    case hotkey = "Hotkey"
    #if PROFEATURES
    case translation = "Translation"
    #endif
    case pro = "Pro"
    case history = "History"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .hotkey: "keyboard"
        #if PROFEATURES
        case .translation: "globe"
        #endif
        case .pro: "sparkles"
        case .history: "clock.arrow.circlepath"
        case .about: "info.circle"
        }
    }
}

struct MainWindowView: View {
    @State private var selection: SidebarSection = .general

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            Group {
                switch selection {
                case .general: GeneralSettingsView()
                case .hotkey: HotkeySettingsView()
                #if PROFEATURES
                case .translation: TranslationSettingsView()
                #endif
                case .pro: ProUpgradeView()
                case .history: HistoryView()
                case .about: AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
