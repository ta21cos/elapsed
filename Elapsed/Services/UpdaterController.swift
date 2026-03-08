import Foundation
import Sparkle

@MainActor
final class UpdaterController: ObservableObject {
    let updater: SPUUpdater

    @Published var canCheckForUpdates = false

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updater = controller.updater

        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)

        controller.startUpdater()
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
