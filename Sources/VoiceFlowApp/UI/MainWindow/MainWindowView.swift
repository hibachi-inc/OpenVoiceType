import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case history = "history"
    case general = "general"
    case hotkey = "hotkey"
    #if PROFEATURES
    case translation = "translation"
    case pro = "pro"
    #endif
    case about = "about"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: String(localized: "sidebar.general")
        case .hotkey: String(localized: "sidebar.hotkey")
        #if PROFEATURES
        case .translation: String(localized: "sidebar.translation")
        case .pro: String(localized: "sidebar.pro")
        #endif
        case .history: String(localized: "sidebar.history")
        case .about: String(localized: "sidebar.about")
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .hotkey: "keyboard"
        #if PROFEATURES
        case .translation: "globe"
        case .pro: "sparkles"
        #endif
        case .history: "clock.arrow.circlepath"
        case .about: "info.circle"
        }
    }
}

struct MainWindowView: View {
    @State private var selection: SidebarSection = .history

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { section in
                Label(section.label, systemImage: section.icon)
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
                case .pro: ProUpgradeView()
                #endif
                case .history: HistoryView()
                case .about: AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
