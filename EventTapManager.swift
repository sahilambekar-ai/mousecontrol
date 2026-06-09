import Cocoa
import CoreGraphics
import Combine
import IOKit
import IOKit.hid

/// A C-style callback function required by CGEvent.tapCreate.
/// Forwards events to the EventTapManager instance passed via the refcon userInfo pointer.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }
    
    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    
    // Check if the OS has disabled our event tap (due to timeout/sleep)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        manager.handleTapDisabled()
        return nil
    }
    
    if let processedEvent = manager.handleEvent(type: type, event: event) {
        return Unmanaged.passUnretained(processedEvent)
    } else {
        // Returning nil suppresses the mouse event from reaching the rest of the OS
        return nil
    }
}

public final class EventTapManager: ObservableObject {
    public static let shared = EventTapManager()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // UI Interaction delegates
    public var onMouseTriggerDetected: ((MouseTrigger) -> Void)?
    public var isRecording: Bool = false
    
    // Track permission caching or creation failure state
    @Published public var hasFailedToStart: Bool = false
    
    // IOHIDManager for physical mouse detection
    private var hidManager: IOHIDManager?
    @Published public var connectedMice: [String] = ["All Devices"]
    @Published public var lastActiveDeviceName: String = "All Devices"
    @Published public var lastActiveTrigger: MouseTrigger? = nil
    @Published public var lastActiveKeyEvent: String = "None"
    
    private init() {
        setupHIDManager()
    }
    
    /// Returns true if the global event tap is currently active.
    public var isRunning: Bool {
        return eventTap != nil
    }
    
    /// Re-enables the event tap if disabled by the OS
    public func handleTapDisabled() {
        print("[EventTapManager] Warning: Event tap was disabled by OS. Re-enabling tap...")
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func logEventToFile(_ message: String) {
        let logPath = "/Users/sahil/Documents/work/practice/mousecontrol/run.log"
        let line = "[\(Date())] \(message)\n"
        if let fileHandle = FileHandle(forWritingAtPath: logPath) {
            fileHandle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }

    /// Starts capturing global mouse events.
    public func start() {
        if isRunning { return }
        
        // Reset or create run.log on start
        let logPath = "/Users/sahil/Documents/work/practice/mousecontrol/run.log"
        try? "=== MouseControl Started at \(Date()) ===\n".write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Listen to all relevant mouse press, release, and scroll events
        // Ensure 64-bit explicit shift values to prevent type inference overflow issues
        let eventMask = (UInt64(1) << CGEventType.otherMouseDown.rawValue)
                      | (UInt64(1) << CGEventType.otherMouseUp.rawValue)
                      | (UInt64(1) << CGEventType.scrollWheel.rawValue)
                      | (UInt64(1) << CGEventType.leftMouseDown.rawValue)
                      | (UInt64(1) << CGEventType.leftMouseUp.rawValue)
                      | (UInt64(1) << CGEventType.rightMouseDown.rawValue)
                      | (UInt64(1) << CGEventType.rightMouseUp.rawValue)
                      | (UInt64(1) << CGEventType.leftMouseDragged.rawValue)
                      | (UInt64(1) << CGEventType.rightMouseDragged.rawValue)
                      | (UInt64(1) << CGEventType.otherMouseDragged.rawValue)
                      | (UInt64(1) << CGEventType.keyDown.rawValue)
                      | (UInt64(1) << CGEventType.keyUp.rawValue)
                      | (UInt64(1) << CGEventType.flagsChanged.rawValue)
                      | (UInt64(1) << 14) // systemDefined / NX_SYSDEFINED
        
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: selfPointer
        ) else {
            print("[EventTapManager] Failed to create CGEventTap. Accessibility permissions are likely missing or permission cache is corrupt.")
            DispatchQueue.main.async {
                self.hasFailedToStart = true
            }
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        DispatchQueue.main.async {
            self.hasFailedToStart = false
        }
        print("[EventTapManager] Event tap successfully installed and started.")
    }
    
    /// Stops capturing mouse events.
    public func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        self.eventTap = nil
        self.runLoopSource = nil
        
        DispatchQueue.main.async {
            self.hasFailedToStart = false
        }
        print("[EventTapManager] Event tap uninstalled and stopped.")
    }
    
    /// Restarts the event tap if running, useful when recovering from an error or permissions grant
    public func restart() {
        stop()
        start()
    }
    
    private func setupHIDManager() {
        if hidManager != nil { return }
        
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.hidManager = manager
        
        let deviceMatch: [String: Any] = [
            "DeviceUsagePage": 0x01,
            "DeviceUsage": 0x02
        ]
        
        IOHIDManagerSetDeviceMatching(manager, deviceMatch as CFDictionary)
        
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { (context, result, sender, device) in
            guard let context = context else { return }
            let manager = Unmanaged<EventTapManager>.fromOpaque(context).takeUnretainedValue()
            manager.updateConnectedMice()
        }, selfPointer)
        
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { (context, result, sender, device) in
            guard let context = context else { return }
            let manager = Unmanaged<EventTapManager>.fromOpaque(context).takeUnretainedValue()
            manager.updateConnectedMice()
        }, selfPointer)
        
        IOHIDManagerRegisterInputValueCallback(manager, { (context, result, sender, value) in
            guard let sender = sender, let context = context else { return }
            let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
            if let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
                let manager = Unmanaged<EventTapManager>.fromOpaque(context).takeUnretainedValue()
                if manager.lastActiveDeviceName != name {
                    manager.lastActiveDeviceName = name
                }
            }
        }, selfPointer)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            print("[EventTapManager] Failed to open IOHIDManager: \(openResult)")
        }
        
        updateConnectedMice()
    }
    
    public func updateConnectedMice() {
        guard let manager = hidManager else { return }
        var miceNames: [String] = ["All Devices"]
        
        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            for device in devices {
                if let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
                    if !miceNames.contains(name) {
                        miceNames.append(name)
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.connectedMice = miceNames
            print("[EventTapManager] Connected mice: \(self.connectedMice)")
        }
    }
    
    public func toggleStageManager() {
        let script = """
        STATE=$(defaults read com.apple.WindowManager GloballyEnabled 2>/dev/null)
        if [ "$STATE" = "1" ]; then
            defaults write com.apple.WindowManager GloballyEnabled -bool false
        else
            defaults write com.apple.WindowManager GloballyEnabled -bool true
        fi
        killall Dock
        """
        
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", script]
        
        DispatchQueue.global(qos: .userInitiated).async {
            process.launch()
            process.waitUntilExit()
            print("[EventTapManager] Stage Manager toggled. Exit code: \(process.terminationStatus)")
        }
    }
    
    /// Processes incoming mouse events.
    /// - Returns: The event to forward to the OS, or nil if the event is swallowed.
    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        // Log all captured events to file for diagnostics
        let typeVal = type.rawValue
        var logMsg = "Event Type: \(typeVal)"
        
        if type == .keyDown || type == .keyUp {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            logMsg += " (Key \(type == .keyDown ? "Down" : "Up")), KeyCode: \(keyCode), Flags: \(event.flags.rawValue)"
        } else if type == .flagsChanged {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            logMsg += " (FlagsChanged), KeyCode: \(keyCode), Flags: \(event.flags.rawValue)"
        } else if type == .otherMouseDown || type == .otherMouseUp {
            let buttonNum = event.getIntegerValueField(.mouseEventButtonNumber)
            logMsg += " (OtherMouse \(type == .otherMouseDown ? "Down" : "Up")), Button: \(buttonNum)"
        } else if type == .leftMouseDown || type == .leftMouseUp {
            logMsg += " (LeftMouse \(type == .leftMouseDown ? "Down" : "Up"))"
        } else if type == .rightMouseDown || type == .rightMouseUp {
            logMsg += " (RightMouse \(type == .rightMouseDown ? "Down" : "Up"))"
        } else if typeVal == 14 {
            let nsEvent = NSEvent(cgEvent: event)
            let subtype = nsEvent?.subtype.rawValue ?? -1
            let data1 = nsEvent?.data1 ?? -1
            let data2 = nsEvent?.data2 ?? -1
            logMsg += " (SystemDefined), Subtype: \(subtype), Data1: \(data1), Data2: \(data2)"
        } else if type == .scrollWheel {
            let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let deltaX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            logMsg += " (Scroll), DeltaY: \(deltaY), DeltaX: \(deltaX)"
        }
        logEventToFile(logMsg)
        
        // Intercept keyboard events for Stage Manager toggle
        if type == .keyDown || type == .keyUp {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            
            // Log keyboard event for real-time debug display
            DispatchQueue.main.async {
                let name = nameForKeyCode(CGKeyCode(keyCode))
                self.lastActiveKeyEvent = "Key \(type == .keyDown ? "Down" : "Up"): \(keyCode) (\(name))"
            }
            
            if AppSettings.shared.toggleStageManagerOnShowDesktop {
                let isF11 = (keyCode == 103)
                let isCmdF3 = (keyCode == 99 && flags.contains(.maskCommand))
                
                if isF11 || isCmdF3 {
                    if type == .keyDown {
                        toggleStageManager()
                    }
                    return nil // Swallow the Show Desktop shortcut!
                }
            }
            return event // Let all other keyboard events pass through immediately!
        }
        
        // Log flagsChanged and systemDefined events to settings view
        if type == .flagsChanged {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            DispatchQueue.main.async {
                let name = nameForKeyCode(CGKeyCode(keyCode))
                self.lastActiveKeyEvent = "FlagsChanged Key: \(keyCode) (\(name)) Flags: \(event.flags.rawValue)"
            }
        } else if typeVal == 14 {
            let nsEvent = NSEvent(cgEvent: event)
            let subtype = nsEvent?.subtype.rawValue ?? -1
            let data1 = nsEvent?.data1 ?? -1
            let data2 = nsEvent?.data2 ?? -1
            DispatchQueue.main.async {
                self.lastActiveKeyEvent = "SystemDefined Subtype:\(subtype) D1:\(data1) D2:\(data2)"
            }
        }
        
        // 1. Handle recording mode (recording a trigger in Settings)
        if isRecording {
            if let trigger = detectTrigger(type: type, event: event) {
                // Ensure we record on the "Down" action or scroll events
                if isDownEvent(type: type) || type == .scrollWheel {
                    DispatchQueue.main.async {
                        self.onMouseTriggerDetected?(trigger)
                    }
                }
                return nil // Swallow events in recording mode to prevent stray clicks
            }
            return event
        }
        
        // 2. If the global mapper is toggled off, let everything pass through
        guard AppSettings.shared.isEnabled else {
            return event
        }
        
        // 3. Match mouse triggers to configured mappings
        if let trigger = detectTrigger(type: type, event: event) {
            // Update last active trigger for UI highlight flashing
            DispatchQueue.main.async {
                self.lastActiveTrigger = trigger
                // Clear the trigger highlight after 0.5s to flash it
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.lastActiveTrigger == trigger {
                        self.lastActiveTrigger = nil
                    }
                }
            }
            
            let activeDevice = self.lastActiveDeviceName
            if let mapping = AppSettings.shared.mappings.first(where: { 
                $0.trigger == trigger && 
                $0.isEnabled && 
                ($0.deviceName == "All Devices" || $0.deviceName == activeDevice)
            }) {
                switch trigger {
                case .button:
                    if isDragEvent(type: type) {
                        return nil // Swallow drag events for mapped buttons without triggering key actions
                    }
                    let isDown = isDownEvent(type: type)
                    KeySimulator.shared.simulateShortcut(
                        keyCode: mapping.shortcut.keyCode,
                        modifiers: mapping.shortcut.modifiers,
                        isDown: isDown
                    )
                    return nil // Swallow the mouse click
                    
                case .scroll:
                    // Since scroll events represent momentum-based 'ticks' with no distinct held duration,
                    // we simulate a full down-then-up tap on each scroll event we capture.
                    KeySimulator.shared.simulateTap(
                        keyCode: mapping.shortcut.keyCode,
                        modifiers: mapping.shortcut.modifiers
                    )
                    return nil // Swallow the scroll wheel notch
                }
            }
        }
        
        return event
    }
    
    /// Helper to identify if an event represents a button click down
    private func isDownEvent(type: CGEventType) -> Bool {
        return type == .otherMouseDown || type == .leftMouseDown || type == .rightMouseDown
    }
    
    /// Helper to identify if an event represents a button click drag
    private func isDragEvent(type: CGEventType) -> Bool {
        return type == .otherMouseDragged || type == .leftMouseDragged || type == .rightMouseDragged
    }
    
    /// Detects the MouseTrigger enum value from a low-level CGEvent.
    private func detectTrigger(type: CGEventType, event: CGEvent) -> MouseTrigger? {
        switch type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            return .button(0)
            
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
            return .button(1)
            
        case .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            let buttonNum = event.getIntegerValueField(.mouseEventButtonNumber)
            return .button(Int(buttonNum))
            
        case .scrollWheel:
            let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let deltaX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            
            // Prioritize vertical scroll, then horizontal scroll
            if deltaY > 0 {
                return .scroll(.up)
            } else if deltaY < 0 {
                return .scroll(.down)
            } else if deltaX > 0 {
                return .scroll(.left)
            } else if deltaX < 0 {
                return .scroll(.right)
            }
            
        default:
            break
        }
        
        return nil
    }
}
