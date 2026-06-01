import SwiftUI
import AppKit

struct HistoryView: View {
    @State private var store = HistoryStore.shared
    @State private var selectedEntry: HistoryEntry?
    private let injector = ClipboardInjector()

    private var coordinator: RecordingCoordinator? {
        (NSApp.delegate as? AppDelegate)?.recordingCoordinator
    }

    var body: some View {
        VStack(spacing: 0) {
            if let coordinator {
                RecordingControl(coordinator: coordinator)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)

                Divider()
            }

            if store.entries.isEmpty {
                ContentUnavailableView(
                    "history.empty",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("history.empty_desc")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(store.entries, id: \.id) { entry in
                            HistoryCard(entry: entry, onDelete: { delete(entry) })
                                .contextMenu {
                                    Button("history.copy") { injector.inject(entry.refinedText) }
                                    Button("history.copy_raw") { injector.inject(entry.rawTranscript) }
                                    Divider()
                                    Button("history.delete", role: .destructive) { delete(entry) }
                                }
                        }
                    }
                    .padding(DS.Spacing.md)
                }
            }
        }
        .navigationTitle(String(localized: "sidebar.history"))
        .toolbar {
            if !store.entries.isEmpty {
                ToolbarItem {
                    Button("history.clear_all", role: .destructive) {
                        store.clearAll()
                    }
                }
            }
        }
    }

    private func delete(_ entry: HistoryEntry) {
        store.delete(entry)
    }
}

// MARK: - Recording Control

struct RecordingControl: View {
    let coordinator: RecordingCoordinator

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Button(action: { coordinator.toggle() }) {
                ZStack {
                    Circle()
                        .fill(coordinator.isRecording ? DS.Colors.recording : DS.Colors.accent)
                        .frame(width: 48, height: 48)
                        .shadow(color: (coordinator.isRecording ? DS.Colors.recording : DS.Colors.accent).opacity(0.4), radius: 8)

                    Image(systemName: coordinator.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                if coordinator.isRecording {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("history.recording")
                            .font(DS.Font.bodyMedium)
                            .foregroundStyle(DS.Colors.recording)

                        if !coordinator.activeEngine.isEmpty {
                            Text(coordinator.activeEngine == "enhanced"
                                ? String(localized: "engine.enhanced_short")
                                : String(localized: "engine.classic_short"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(coordinator.activeEngine == "enhanced" ? DS.Colors.accent : DS.Colors.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background((coordinator.activeEngine == "enhanced" ? DS.Colors.accent : DS.Colors.secondary).opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    if !coordinator.currentTranscript.isEmpty {
                        Text(coordinator.currentTranscript)
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.secondary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                } else {
                    Text("history.tap_to_start")
                        .font(DS.Font.bodyMedium)
                        .foregroundStyle(DS.Colors.secondary)
                }
            }

            Spacer()
        }
        .animation(DS.Animation.content, value: coordinator.isRecording)
    }
}

// MARK: - History Card

struct HistoryCard: View {
    let entry: HistoryEntry
    var onDelete: () -> Void = {}
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            #if PROFEATURES
            HStack {
                Text(entry.appName)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Colors.accent.opacity(0.1))
                    .clipShape(Capsule())

                Text(entry.category)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)

                Spacer()

                Text(relativeTime(entry.timestamp))
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)

                Button(action: copyText) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(copied ? .green : DS.Colors.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help(String(localized: "history.copy"))
            }
            #endif

            Text(entry.refinedText)
                .font(DS.Font.body)
                .lineLimit(3)

            if entry.rawTranscript != entry.refinedText {
                Text(entry.rawTranscript)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
                    .lineLimit(1)
            }

            #if !PROFEATURES
            HStack {
                Text(relativeTime(entry.timestamp))
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)

                Spacer()

                Button(action: copyText) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(copied ? .green : DS.Colors.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help(String(localized: "history.copy"))
            }
            #endif
        }
        .padding(DS.Spacing.md)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.refinedText, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return String(localized: "history.just_now") }
        let minutes = seconds / 60
        if minutes < 60 { return String(localized: "history.minutes_ago \(minutes)") }
        let hours = minutes / 60
        if hours < 24 { return String(localized: "history.hours_ago \(hours)") }
        let days = hours / 24
        return String(localized: "history.days_ago \(days)")
    }
}
