import Foundation

@MainActor
final class AppModel: ObservableObject {
    let store: ClipStore
    let monitor: ClipboardMonitor

    init() {
        store = ClipStore()
        monitor = ClipboardMonitor(store: store)
        monitor.start()
    }

    func copy(_ item: ClipItem) {
        monitor.ignoreNextChange = true
        store.copyToPasteboard(item)
    }
}
