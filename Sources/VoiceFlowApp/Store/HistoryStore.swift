import Foundation
import SwiftData

@Model
final class HistoryEntry {
    @Attribute(.unique) var id: UUID
    var rawTranscript: String
    var refinedText: String
    var appName: String
    var category: String
    var siteDomain: String?
    var timestamp: Date

    init(rawTranscript: String, refinedText: String, appName: String, category: String, siteDomain: String? = nil) {
        self.id = UUID()
        self.rawTranscript = rawTranscript
        self.refinedText = refinedText
        self.appName = appName
        self.category = category
        self.siteDomain = siteDomain
        self.timestamp = Date()
    }

    /// Display key: domain for browser sites, app name otherwise
    var promptKey: String { siteDomain ?? appName }
}

@MainActor
@Observable
final class HistoryStore {
    static let shared = HistoryStore()

    private(set) var entries: [HistoryEntry] = []

    let container: ModelContainer
    let context: ModelContext

    private let maxEntries = 50

    private init() {
        let schema = Schema([HistoryEntry.self])
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDir = appSupport.appendingPathComponent("OpenVoiceText", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let storeURL = storeDir.appendingPathComponent("history.store")
        let diskConfig = ModelConfiguration(url: storeURL)
        let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            container = try ModelContainer(for: schema, configurations: [diskConfig])
        } catch {
            container = try! ModelContainer(for: schema, configurations: [memoryConfig])
        }
        context = ModelContext(container)
        reload()
    }

    func add(rawTranscript: String, refinedText: String, appName: String, category: String, siteDomain: String? = nil) {
        let entry = HistoryEntry(
            rawTranscript: rawTranscript,
            refinedText: refinedText,
            appName: appName,
            category: category,
            siteDomain: siteDomain
        )
        context.insert(entry)
        try? context.save()
        reload()
        trimOldEntries()
    }

    func delete(_ entry: HistoryEntry) {
        context.delete(entry)
        try? context.save()
        reload()
    }

    func clearAll() {
        for entry in entries { context.delete(entry) }
        try? context.save()
        reload()
    }

    func reload() {
        let descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        entries = (try? context.fetch(descriptor)) ?? []
    }

    private func trimOldEntries() {
        let all = entries
        guard all.count > maxEntries else { return }
        for entry in all.suffix(from: maxEntries) {
            context.delete(entry)
        }
    }
}
