import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    let store: ClipStore
    let monitor: ClipboardMonitor

    /// Bridges `ClipStore`'s changes into `AppModel`'s own publisher.
    ///
    /// Without this, SwiftUI views that observe `AppModel` never re-render when
    /// a new item is captured, because the items live on `store` (a separate
    /// `ObservableObject`). That made the panel look frozen at launch.
    private var storeObserver: AnyCancellable?

    init() {
        store = ClipStore()
        monitor = ClipboardMonitor(store: store)

        storeObserver = store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        monitor.start()
    }

    private var careTimer: Timer?

    func copy(_ item: ClipItem) {
        monitor.ignoreNextChange = true
        store.copyToPasteboard(item)
        store.markUsed(item)
    }

    /// Smart cleanup at launch and hourly.
    func startCare(isPanelOpen: @escaping () -> Bool) {
        store.cleanUp()
        // Every 5 minutes, so one-time codes really go after ~20 minutes.
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in if !isPanelOpen() { self?.store.cleanUp() } }
        }
        RunLoop.main.add(t, forMode: .common)
        careTimer = t
    }
}
