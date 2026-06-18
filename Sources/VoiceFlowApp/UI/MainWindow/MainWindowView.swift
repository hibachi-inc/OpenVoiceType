import SwiftUI

extension Notification.Name {
    static let openProSettings = Notification.Name("openProSettings")
}

enum SidebarSection: String, Identifiable {
    case history = "history"
    case general = "general"
    case hotkey = "hotkey"
    #if PROFEATURES
    case pro = "pro"
    case translation = "translation"
    case customRefine = "customRefine"
    #endif
    case about = "about"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: String(localized: "sidebar.general")
        case .hotkey: String(localized: "sidebar.hotkey")
        #if PROFEATURES
        case .pro: String(localized: "sidebar.pro")
        case .translation: Bundle.main.localizedString(forKey: "sidebar.translation", value: "Quick Translate", table: nil)
        case .customRefine: String(localized: "sidebar.custom_refine")
        #endif
        case .history: Bundle.main.localizedString(forKey: "sidebar.voice_history", value: "Voice History", table: nil)
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
        case .customRefine: "slider.horizontal.3"
        #endif
        case .history: "clock.arrow.circlepath"
        case .about: "info.circle"
        }
    }

    static let freeItems: [SidebarSection] = [.history, .general, .hotkey]
    #if PROFEATURES
    static var proItems: [SidebarSection] {
        var items: [SidebarSection] = [.translation, .customRefine]
        if ProUpgradeManager.monetizationEnabled {
            items.insert(.pro, at: 0)
        }
        return items
    }
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
                case .customRefine: CustomRefineSettingsView()
                case .pro: ProUpgradeView()
                #endif
                case .history: HistoryView()
                case .about: AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(DS.Colors.primary)
            .tint(DS.Colors.accent)
            .background(DS.Colors.windowBg)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openProSettings)) { _ in
            #if PROFEATURES
            if ProUpgradeManager.monetizationEnabled {
                selection = .pro
            }
            #endif
        }
    }
}
