import Carbon.HIToolbox
import AppKit

/// Registers a system-wide hotkey using the Carbon Hot Key API.
/// Carbon hotkeys do not require Accessibility permissions.
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onPressed: (() -> Void)?

    /// Default: ⌥V (Option + V)
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_V),
                  modifiers: UInt32 = UInt32(optionKey)) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onPressed?() }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(),
                            handler,
                            1,
                            &eventType,
                            Unmanaged.passUnretained(self).toOpaque(),
                            &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // 'CLIP'
        let status = RegisterEventHotKey(keyCode,
                                         modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        if status != noErr {
            NSLog("GsClipboard: failed to register hotkey (status \(status))")
        } else {
            NSLog("GsClipboard: hotkey ⌥V registered")
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
