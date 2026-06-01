import Carbon.HIToolbox
import AppKit

@MainActor private var globalHotkeyRegistry: [UInt32: () -> Void] = [:]
@MainActor private var globalHandlerInstalled = false
@MainActor private var globalHandlerRef: EventHandlerRef?
@MainActor private var globalNextID: UInt32 = 1

@MainActor private func installGlobalHandlerIfNeeded() {
    guard !globalHandlerInstalled else { return }

    var eventType = EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard),
        eventKind: UInt32(kEventHotKeyPressed)
    )

    let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else { return OSStatus(eventNotHandledErr) }

        let id = hotKeyID.id
        Task { @MainActor in
            globalHotkeyRegistry[id]?()
        }
        return noErr
    }

    InstallEventHandler(
        GetApplicationEventTarget(),
        handler,
        1,
        &eventType,
        nil,
        &globalHandlerRef
    )
    globalHandlerInstalled = true
}

@MainActor
final class GlobalHotkey {
    private var hotkeyRef: EventHotKeyRef?
    private let hotkeyID: UInt32

    init() {
        hotkeyID = globalNextID
        globalNextID += 1
    }

    func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        unregister()
        globalHotkeyRegistry[hotkeyID] = callback
        installGlobalHandlerIfNeeded()

        var id = EventHotKeyID(signature: OSType(0x4F565478), id: hotkeyID)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
    }

    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        globalHotkeyRegistry.removeValue(forKey: hotkeyID)
    }
}

extension HotkeyModifier {
    var carbonModifier: UInt32 {
        switch self {
        case .option: UInt32(optionKey)
        case .control: UInt32(controlKey)
        case .command: UInt32(cmdKey)
        }
    }
}
