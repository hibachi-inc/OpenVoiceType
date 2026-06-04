#if DIRECT
@preconcurrency import Sparkle

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
        controller.startUpdater()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }

    var canCheck: Bool { controller.updater.canCheckForUpdates }
}
#endif
