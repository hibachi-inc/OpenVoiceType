#if DIRECT
@preconcurrency import Sparkle
import UserNotifications

/// Thin wrapper around Sparkle for DMG auto-update.
/// MAS builds use App Store updates — this file is compiled out via #if DIRECT.
@MainActor
final class SparkleUpdater: NSObject {
    private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func start() {
        requestNotificationPermission()
        controller?.startUpdater()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        controller?.checkForUpdates(sender)
    }

    var canCheck: Bool { controller?.updater.canCheckForUpdates ?? false }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postUpdateNotification(version: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "VoiceLatte"
        content.body = String(format: NSLocalizedString("update.available %@", comment: ""), version)
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
