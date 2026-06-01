import Foundation
import Speech

@available(macOS 26, *)
@MainActor
@Observable
final class SpeechModelManager {
    static let shared = SpeechModelManager()

    enum ModelStatus: Equatable {
        case checking
        case installed
        case notInstalled
        case unsupported
        case downloading(Double)
        case error(String)
    }

    private(set) var status: ModelStatus = .checking
    private var downloadTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var checkTask: Task<Void, Never>?

    func checkStatus() {
        guard downloadTask == nil else { return }
        checkTask?.cancel()
        status = .checking
        let task = Task {
            let locale = currentLocale()
            guard await supported(locale: locale) else {
                guard !Task.isCancelled else { return }
                status = .unsupported
                return
            }
            let isInstalled = await installed(locale: locale)
            guard !Task.isCancelled else { return }
            status = isInstalled ? .installed : .notInstalled
        }
        checkTask = task
    }

    func download() {
        guard downloadTask == nil else { return }
        status = .downloading(0)
        downloadTask = Task {
            defer {
                downloadTask = nil
                progressTask?.cancel()
                progressTask = nil
            }
            do {
                let locale = currentLocale()
                let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
                guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                    status = .installed
                    return
                }
                let progress = request.progress
                progressTask = Task { @MainActor [weak self] in
                    while !Task.isCancelled, !progress.isFinished, !progress.isCancelled {
                        self?.status = .downloading(progress.fractionCompleted)
                        try? await Task.sleep(for: .milliseconds(200))
                        if Task.isCancelled { return }
                    }
                }
                try await request.downloadAndInstall()
                guard !Task.isCancelled else { return }
                status = .installed
            } catch {
                guard !Task.isCancelled else { return }
                status = .error(error.localizedDescription)
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        progressTask?.cancel()
        progressTask = nil
        checkStatus()
    }

    private func currentLocale() -> Locale {
        let prefs = PreferencesStore.shared
        let raw = prefs.locale == "system" ? Locale.current.identifier : prefs.locale
        return Locale(identifier: raw)
    }

    private func supported(locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        let bcp47 = locale.identifier(.bcp47)
        return supported.contains { $0.identifier(.bcp47) == bcp47 }
    }

    private func installed(locale: Locale) async -> Bool {
        let installed = await SpeechTranscriber.installedLocales
        let bcp47 = locale.identifier(.bcp47)
        return installed.contains { $0.identifier(.bcp47) == bcp47 }
    }
}
