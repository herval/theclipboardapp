import Cocoa
import Carbon

class GlobalHotkeyMonitor {
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextHotkeyID: UInt32 = 1
    private var installedEventHandler = false
    
    init() {
        installEventHandlerIfNeeded()
    }
    
    /// Registers a set of default hotkeys with their handlers. Call this from AppDelegate.
    func registerDefaultHotkeys(clipboardHistoryHandler: @escaping () -> Void, additional: [(keyCode: UInt32, modifiers: UInt32, handler: () -> Void)] = []) {
        // Cmd+Shift+C (keyCode 8)
        registerHotkey(keyCode: 8, modifiers: cmdKey | shiftKey, handler: clipboardHistoryHandler)
        // Register any additional hotkeys
        for entry in additional {
            registerHotkey(keyCode: entry.keyCode, modifiers: entry.modifiers, handler: entry.handler)
        }
    }
    
    deinit {
        unregisterAllHotkeys()
    }
    
    /// Registers a global hotkey with a handler. Returns the hotkey ID for future reference.
    @discardableResult
    func registerHotkey(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> UInt32 {
        let hotkeyID = nextHotkeyID
        nextHotkeyID += 1
        let signature = OSType(UInt32(truncatingIfNeeded: "CLPB".hashValue))
        var eventHotKeyID = EventHotKeyID(signature: signature, id: hotkeyID)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, eventHotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status == noErr, let hotKeyRef = hotKeyRef {
            hotKeyRefs[hotkeyID] = hotKeyRef
            handlers[hotkeyID] = handler
        } else {
            print("Failed to register global hotkey: status=\(status)")
        }
        return hotkeyID
    }
    
    private func unregisterAllHotkeys() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
    }
    
    private func installEventHandlerIfNeeded() {
        guard !installedEventHandler else { return }
        installedEventHandler = true
        let eventHandler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if hkID.signature == OSType(UInt32(truncatingIfNeeded: "CLPB".hashValue)), let userData = userData {
                let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                if let handler = monitor.handlers[hkID.id] {
                    handler()
                }
                return noErr
            }
            return noErr
        }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), eventHandler, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), nil)
    }
}

// Carbon modifier constants
let cmdKey: UInt32 = 0x100
let optionKey: UInt32 = 0x800
let shiftKey: UInt32 = 0x200
let controlKey: UInt32 = 0x400
