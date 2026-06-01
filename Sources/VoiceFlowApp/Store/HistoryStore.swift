import Foundation
import SwiftData

@Model
final class HistoryEntry {
    @Attribute(.unique) var id: UUID
    var rawTranscript: String
    var refinedText: String
    var appName: String
    var category: String
    var timestamp: Date

    init(rawTranscript: String, refinedText: String, appName: String, category: String) {
        self.id = UUID()
        self.rawTranscript = rawTranscript
        self.refinedText = refinedText
        self.appName = appName
        self.category = category
        self.timestamp = Date()
    }
}

@MainActor
final class HistoryStore {
    static let shared = HistoryStore()

    let container: ModelContainer
    let context: ModelContext

    private let maxEntries = 50

    private init() {
        let schema = Schema([HistoryEntry.self])
        let diskConfig = ModelConfiguration(isStoredInMemoryOnly: false)
        let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            container = try ModelContainer(for: schema, configurations: [diskConfig])
        } catch {
            // Fallback to in-memory if disk store is corrupted (e.g. schema migration failure)
            container = try! ModelContainer(for: schema, configurations: [memoryConfig])
        }
        context = ModelContext(container)
    }

    func add(rawTranscript: String, refinedText: String, appName: String, category: String) {
        let entry = HistoryEntry(
            rawTranscript: rawTranscript,
            refinedText: refinedText,
            appName: appName,
            category: category
        )
        context.insert(entry)
        trimOldEntries()
        try? context.save()
    }

    func fetchAll() -> [HistoryEntry] {
        let descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func delete(_ entry: HistoryEntry) {
        context.delete(entry)
        try? context.save()
    }

    func clearAll() {
        let entries = fetchAll()
        for entry in entries { context.delete(entry) }
        try? context.save()
    }

    private func trimOldEntries() {
        let all = fetchAll()
        guard all.count > maxEntries else { return }
        for entry in all.suffix(from: maxEntries) {
            context.delete(entry)
        }
    }
}
