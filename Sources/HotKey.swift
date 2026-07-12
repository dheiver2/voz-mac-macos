import Foundation
import AppKit
import Carbon.HIToolbox

/// Atalho global ⌃⌥Space para alternar a gravação de qualquer lugar do sistema.
/// Usa a API de hotkeys do Carbon (nativa) — registra sem interceptar teclas comuns.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if hkID.id == 1 {
                DispatchQueue.main.async { me.action() }
            }
            return noErr
        }, 1, &spec, selfPtr, &handler)

        let id = EventHotKeyID(signature: OSType(0x564D4143 /* 'VMAC' */), id: 1)
        let mods = UInt32(controlKey | optionKey)
        RegisterEventHotKey(UInt32(kVK_Space), mods, id,
                            GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
