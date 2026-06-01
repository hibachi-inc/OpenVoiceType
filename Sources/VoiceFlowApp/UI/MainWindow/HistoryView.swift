import SwiftUI

struct HistoryView: View {
    @State private var entries: [HistoryEntry] = []
    @State private var selectedEntry: HistoryEntry?
    private let injector = ClipboardInjector()

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Voice input history will appear here.")
                )
            } else {
                List(entries, id: \.id, selection: $selectedEntry) { entry in
                    HistoryRow(entry: entry)
                        .contextMenu {
                            Button("Copy to Clipboard") { injector.inject(entry.refinedText) }
                            Button("Copy Raw Transcript") { injector.inject(entry.rawTranscript) }
                            Divider()
                            Button("Delete", role: .destructive) { delete(entry) }
                        }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem {
                    Button("Clear All", role: .destructive) {
                        HistoryStore.shared.clearAll()
                        reload()
                    }
                }
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        entries = HistoryStore.shared.fetchAll()
    }

    private func delete(_ entry: HistoryEntry) {
        HistoryStore.shared.delete(entry)
        reload()
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
            }

            Text(entry.refinedText)
                .font(DS.Font.body)
                .lineLimit(3)

            if entry.rawTranscript != entry.refinedText {
                Text(entry.rawTranscript)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "Just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
