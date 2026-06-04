import SwiftUI

enum SidebarSection: String, Identifiable {
    case history = "history"
    case general = "general"
    case hotkey = "hotkey"
    #if PROFEATURES
    case pro = "pro"
    case translation = "translation"
    #endif
    case about = "about"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: String(localized: "sidebar.general")
        case .hotkey: String(localized: "sidebar.hotkey")
        #if PROFEATURES
        case .pro: String(localized: "sidebar.pro")
        case .translation: String(localized: "sidebar.translation")
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
        case .pro: "sparkles"
        case .translation: "globe"
        #endif
        case .history: "clock.arrow.circlepath"
        case .about: "info.circle"
        }
    }

    static let freeItems: [SidebarSection] = [.history, .general, .hotkey]
    #if PROFEATURES
    static let proItems: [SidebarSection] = [.pro, .translation]
    #endif
    static let otherItems: [SidebarSection] = [.about]
}

struct MainWindowView: View {
    @State private var selection: SidebarSection = .history

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(SidebarSection.freeItems) { section in
                        Label(section.label, systemImage: section.icon).tag(section)
                    }
                }
                #if PROFEATURES
                Section {
                    ForEach(SidebarSection.proItems) { section in
                        Label(section.label, systemImage: section.icon).tag(section)
                    }
                }
                #endif
                Section {
                    ForEach(SidebarSection.otherItems) { section in
                        Label(section.label, systemImage: section.icon).tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(DS.Colors.sidebarBg)
            .environment(\.colorScheme, .dark)
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
            .background(DS.Colors.windowBg)
        }
    }
}
