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

    func copy(_ item: ClipItem) {
        monitor.ignoreNextChange = true
        store.copyToPasteboard(item)
    }
}
