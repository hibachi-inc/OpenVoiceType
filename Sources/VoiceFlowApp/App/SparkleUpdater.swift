#if DIRECT
@preconcurrency import Sparkle
import UserNotifications

/// Thin wrapper around Sparkle for DMG auto-update.
/// MAS builds use App Store updates — this file is compiled out via #if DIRECT.
@MainActor
final class SparkleUpdater: NSObject {
    private let controller: SPUStandardUpdaterController

    override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    /// Call from applicationDidFinishLaunching to start the updater after app is fully initialized.
    func start() {
        requestNotificationPermission()
        controller.updater.delegate = self
        controller.startUpdater()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }

    var canCheck: Bool { controller.updater.canCheckForUpdates }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postUpdateNotification(version: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "VoiceLatte"
        content.body = String(
            localized: "update.available \(version)",
            defaultValue: "Version \(version) is available. Open VoiceLatte to update."
        )
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "voicelatte-update-\(version)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}

extension SparkleUpdater: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor in
            postUpdateNotification(version: version)
        }
    }
}
#endif
