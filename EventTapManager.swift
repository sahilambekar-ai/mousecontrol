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
    @Published public var connectedMouseDeviceKeys = Set<String>()
    private var registryIDCache = [UInt64: (vendorID: Int, productID: Int)]()
    @Published public var lastActiveDeviceName: String = "All Devices"
    @Published public var lastActiveDeviceVendorID: Int = 0
    @Published public var lastActiveDeviceProductID: Int = 0
    @Published public var lastActiveTrigger: MouseTrigger? = nil
    @Published public var lastActiveKeyEvent: String = "None"
    @Published public var rawHIDEvents: [RawHIDEvent] = []
    @Published public var isHoveringControl = false
    
    // Scroll Drag State tracking for mapping button to "Scroll (Drag Mouse)"
    private var isScrollDragActive = false
    private var scrollDragStartPoint: CGPoint = .zero
    private var scrollDragTrigger: MouseTrigger? = nil
    
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
                      | (UInt64(1) << CGEventType.mouseMoved.rawValue)
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
        
        // Match ALL connected HID devices to capture consumer control & secondary interfaces of the mouse
        IOHIDManagerSetDeviceMatching(manager, nil)
        
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
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown Device"
            
            let manager = Unmanaged<EventTapManager>.fromOpaque(context).takeUnretainedValue()
            if manager.lastActiveDeviceName != name {
                manager.lastActiveDeviceName = name
            }
            
            let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
            let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
            if manager.lastActiveDeviceVendorID != vendorID || manager.lastActiveDeviceProductID != productID {
                manager.lastActiveDeviceVendorID = vendorID
                manager.lastActiveDeviceProductID = productID
            }
            
            let element = IOHIDValueGetElement(value)
            let usagePage = Int(IOHIDElementGetUsagePage(element))
            let usage = Int(IOHIDElementGetUsage(element))
            let val = IOHIDValueGetIntegerValue(value)
            
            DispatchQueue.main.async {
                let event = RawHIDEvent(deviceName: name, vendorID: vendorID, productID: productID, usagePage: usagePage, usage: usage, value: val)
                manager.rawHIDEvents.insert(event, at: 0)
                if manager.rawHIDEvents.count > 100 {
                    manager.rawHIDEvents.removeLast()
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
    
    private func getDeviceIdentifiers(registryID: UInt64) -> (vendorID: Int, productID: Int)? {
        if let cached = registryIDCache[registryID] {
            return cached
        }
        
        let matchingDict = IORegistryEntryIDMatching(registryID)
        guard matchingDict != nil else { return nil }
        
        let entry = IOServiceGetMatchingService(0, matchingDict)
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        
        let vendorVal = IORegistryEntrySearchCFProperty(
            entry,
            kIOServicePlane,
            kIOHIDVendorIDKey as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateParents | kIORegistryIterateRecursively)
        )
        
        let productVal = IORegistryEntrySearchCFProperty(
            entry,
            kIOServicePlane,
            kIOHIDProductIDKey as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateParents | kIORegistryIterateRecursively)
        )
        
        let vendorID = vendorVal as? Int ?? 0
        let productID = productVal as? Int ?? 0
        
        let ids = (vendorID, productID)
        registryIDCache[registryID] = ids
        return ids
    }
    
    public func isEventFromMouse(event: CGEvent) -> Bool {
        let registryID = event.getIntegerValueField(CGEventField(rawValue: 87)!)
        if registryID != 0 {
            if let ids = getDeviceIdentifiers(registryID: UInt64(registryID)) {
                let key = "\(ids.vendorID)-\(ids.productID)"
                if connectedMouseDeviceKeys.contains(key) {
                    return true
                }
            }
        }
        let key = "\(lastActiveDeviceVendorID)-\(lastActiveDeviceProductID)"
        if connectedMouseDeviceKeys.contains(key) {
            return true
        }
        return self.connectedMice.contains(self.lastActiveDeviceName) && self.lastActiveDeviceName != "All Devices"
    }
    
    public func updateConnectedMice() {
        guard let manager = hidManager else { return }
        var miceNames: [String] = ["All Devices"]
        var deviceKeys = Set<String>()
        
        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            for device in devices {
                let usage = IOHIDDeviceGetProperty(device, "PrimaryUsage" as CFString) as? Int ?? 0
                let usagePage = IOHIDDeviceGetProperty(device, "PrimaryUsagePage" as CFString) as? Int ?? 0
                if usage == 0x02 && usagePage == 0x01 {
                    if let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
                        if !miceNames.contains(name) {
                            miceNames.append(name)
                        }
                    }
                    let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
                    let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
                    if vendorID != 0 && productID != 0 {
                        deviceKeys.insert("\(vendorID)-\(productID)")
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.connectedMice = miceNames
            self.connectedMouseDeviceKeys = deviceKeys
            let msg = "[EventTapManager] Connected mice: \(self.connectedMice), keys: \(self.connectedMouseDeviceKeys)"
            print(msg)
            self.logEventToFile(msg)
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
        // Handle active scroll-drag (pan scroll) mode
        if isScrollDragActive {
            if let dragTrigger = scrollDragTrigger, let trigger = detectTrigger(type: type, event: event), trigger == dragTrigger {
                if type == .leftMouseUp || type == .rightMouseUp || type == .otherMouseUp || type == .keyUp {
                    isScrollDragActive = false
                    scrollDragTrigger = nil
                    return nil // Swallow release
                }
            }
            
            if type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged {
                let currentPoint = event.location
                let dX = currentPoint.x - scrollDragStartPoint.x
                let dY = currentPoint.y - scrollDragStartPoint.y
                
                let threshold: CGFloat = 8.0
                if abs(dX) >= threshold || abs(dY) >= threshold {
                    let scrollY = Int32(-dY / threshold)
                    let scrollX = Int32(dX / threshold)
                    
                    if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: scrollY, wheel2: scrollX, wheel3: 0) {
                        scrollEvent.post(tap: CGEventTapLocation.cghidEventTap)
                    }
                    
                    CGWarpMouseCursorPosition(scrollDragStartPoint)
                }
                return nil // Swallow mouse movement/dragging
            }
        }

        // Log all captured events to file for diagnostics
        let typeVal = type.rawValue
        let regID = event.getIntegerValueField(CGEventField(rawValue: 87)!)
        var logMsg = "Event Type: \(typeVal) (RegID: \(regID))"
        
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
        if type == .keyDown || type == .keyUp || type == .flagsChanged {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            
            // Log keyboard event for real-time debug display
            if type == .keyDown || type == .keyUp {
                DispatchQueue.main.async {
                    let name = nameForKeyCode(CGKeyCode(keyCode))
                    self.lastActiveKeyEvent = "Key \(type == .keyDown ? "Down" : "Up"): \(keyCode) (\(name))"
                }
            } else if type == .flagsChanged {
                DispatchQueue.main.async {
                    let name = nameForKeyCode(CGKeyCode(keyCode))
                    self.lastActiveKeyEvent = "FlagsChanged Key: \(keyCode) (\(name)) Flags: \(flags.rawValue)"
                }
            }
            
            let isStageManagerActive = AppSettings.shared.toggleStageManagerOnShowDesktop
            let isMissionControlActive = AppSettings.shared.toggleMissionControlOnShowDesktop
            
            if (type == .keyDown || type == .keyUp) && (isStageManagerActive || isMissionControlActive) {
                // Identify if the event originated from a registered mouse device (ignoring actual keyboards)
                let isFromMouse = self.isEventFromMouse(event: event)
                
                let isF11 = (keyCode == 103)
                let isCmdF3 = (keyCode == 99 && flags.contains(.maskCommand))
                
                // Intercept Cmd + D (keycode 2) OR raw D/F3 when sent by the mouse device
                let isCmdD = (keyCode == 2 && flags.contains(.maskCommand) && isFromMouse)
                let isF3OrDFromMouse = (keyCode == 99 || keyCode == 2) && isFromMouse
                
                if isF11 || isCmdF3 || isCmdD || isF3OrDFromMouse {
                    if type == .keyDown {
                        if isStageManagerActive {
                            toggleStageManager()
                        } else {
                            // Simulate Ctrl + Up Arrow (Mission Control)
                            KeySimulator.shared.simulateTap(keyCode: 126, modifiers: ModifierFlags(control: true))
                        }
                    }
                    return nil // Swallow the Show Desktop shortcut!
                }
            }
            
            // Swallow modifier key events (Command is keycode 54 or 55) if Stage Manager / Mission Control is active
            if type == .flagsChanged && (isStageManagerActive || isMissionControlActive) {
                let isFromMouse = self.isEventFromMouse(event: event)
                if (keyCode == 54 || keyCode == 55) && isFromMouse {
                    // On key release (Flags: 256, no command mask)
                    if !flags.contains(.maskCommand) && isMissionControlActive {
                        // Simulate Ctrl + Up Arrow (Mission Control)
                        KeySimulator.shared.simulateTap(keyCode: 126, modifiers: ModifierFlags(control: true))
                    }
                    return nil // Swallow the Command key press/release from the mouse!
                }
            }
            
            // If it is a key event from the mouse, we want to intercept it and not let it pass through
            let isFromMouse = self.isEventFromMouse(event: event)
            if isFromMouse && !isRecording {
                // Check if we have a mapping for this mouse key (with modifiers)
                if let trigger = detectTrigger(type: type, event: event) {
                    let activeDevice = self.lastActiveDeviceName
                    if AppSettings.shared.mappings.contains(where: { 
                        $0.trigger == trigger && 
                        $0.isEnabled && 
                        $0.profileName == AppSettings.shared.activeProfile &&
                        ($0.deviceName == "All Devices" || $0.deviceName == activeDevice)
                    }) {
                        // Let the mapping code handle it below
                    } else {
                        return event // Let standard unmapped mouse keyboard events through
                    }
                } else {
                    return event
                }
            } else if !isFromMouse {
                return event // Let all other keyboard events pass through immediately!
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
            if isHoveringControl {
                return event // Let the click through so controls can be clicked!
            }
            if let trigger = detectTrigger(type: type, event: event) {
                // Ensure we record on the "Down" action, key down, scroll, systemDefined, or flagsChanged down events
                let isDown = isDownEvent(type: type) || 
                             type == .scrollWheel || 
                             type == .keyDown || 
                             type.rawValue == 14 || 
                             (type == .flagsChanged && isFlagsChangedDown(event: event))
                             
                if isDown {
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
                $0.profileName == AppSettings.shared.activeProfile &&
                ($0.deviceName == "All Devices" || $0.deviceName == activeDevice)
            }) {
                // Check if mapping is a virtual scroll action
                if mapping.shortcut.keyCode >= 2000 && mapping.shortcut.keyCode <= 2004 {
                    let isDown: Bool
                    if type == .flagsChanged {
                        isDown = isFlagsChangedDown(event: event)
                    } else {
                        isDown = isDownEvent(type: type) || type == .keyDown
                    }
                    if isDown {
                        if mapping.shortcut.keyCode == 2004 {
                            // "Scroll (Drag Mouse)"
                            isScrollDragActive = true
                            scrollDragStartPoint = event.location
                            scrollDragTrigger = trigger
                        } else {
                            // Single scroll ticks (Scroll Up/Down/Left/Right)
                            let direction: ScrollDirection
                            switch mapping.shortcut.keyCode {
                            case 2000: direction = .up
                            case 2001: direction = .down
                            case 2002: direction = .left
                            case 2003: direction = .right
                            default: return nil
                            }
                            simulateScroll(direction: direction)
                        }
                    } else {
                        // KeyUp / MouseUp: if we released the scroll-drag trigger, turn it off
                        if trigger == scrollDragTrigger {
                            isScrollDragActive = false
                            scrollDragTrigger = nil
                        }
                    }
                    return nil // Swallow the click/key press
                }

                switch trigger {
                case .button, .mouseKey:
                    if isDragEvent(type: type) {
                        return nil // Swallow drag events for mapped buttons without triggering key actions
                    }
                    let isDown: Bool
                    if type == .flagsChanged {
                        isDown = isFlagsChangedDown(event: event)
                    } else {
                        isDown = isDownEvent(type: type) || type == .keyDown
                    }
                    KeySimulator.shared.simulateShortcut(
                        keyCode: mapping.shortcut.keyCode,
                        modifiers: mapping.shortcut.modifiers,
                        isDown: isDown
                    )
                    return nil // Swallow the mouse click or key press
                    
                case .scroll, .systemEvent:
                    // Since scroll and systemDefined events represent ticks or momentary system events with no distinct held duration,
                    // we simulate a full down-then-up tap on each event we capture.
                    KeySimulator.shared.simulateTap(
                        keyCode: mapping.shortcut.keyCode,
                        modifiers: mapping.shortcut.modifiers
                    )
                    return nil // Swallow the event
                }
            }
        }
        
        return event
    }
    
    /// Helper to identify if an event represents a button click down
    private func isDownEvent(type: CGEventType) -> Bool {
        return type == .otherMouseDown || type == .leftMouseDown || type == .rightMouseDown
    }
    
    private func isFlagsChangedDown(event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        switch keyCode {
        case 54, 55: return flags.contains(.maskCommand)
        case 56, 60: return flags.contains(.maskShift)
        case 59, 62: return flags.contains(.maskControl)
        case 58, 61: return flags.contains(.maskAlternate)
        default: return false
        }
    }
    
    /// Helper to identify if an event represents a button click drag
    private func isDragEvent(type: CGEventType) -> Bool {
        return type == .otherMouseDragged || type == .leftMouseDragged || type == .rightMouseDragged
    }
    
    private func simulateScroll(direction: ScrollDirection) {
        var scrollY: Int32 = 0
        var scrollX: Int32 = 0
        switch direction {
        case .up: scrollY = 1
        case .down: scrollY = -1
        case .left: scrollX = -1
        case .right: scrollX = 1
        }
        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: scrollY, wheel2: scrollX, wheel3: 0) {
            scrollEvent.post(tap: CGEventTapLocation.cghidEventTap)
        }
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
            
        case .keyDown, .keyUp, .flagsChanged:
            if self.isEventFromMouse(event: event) {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                
                var hasCmd = flags.contains(.maskCommand)
                var hasCtrl = flags.contains(.maskControl)
                var hasOpt = flags.contains(.maskAlternate)
                var hasShift = flags.contains(.maskShift)
                
                // For flagsChanged, if the key itself is a modifier, we force its flag to be true
                // so that the release event (which has the flag cleared) still matches the trigger.
                if type == .flagsChanged {
                    switch keyCode {
                    case 54, 55: hasCmd = true
                    case 56, 60: hasShift = true
                    case 59, 62: hasCtrl = true
                    case 58, 61: hasOpt = true
                    default: break
                    }
                }
                
                return .mouseKey(
                    keyCode: Int(keyCode),
                    hasCmd: hasCmd,
                    hasCtrl: hasCtrl,
                    hasOpt: hasOpt,
                    hasShift: hasShift
                )
            }
            
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
            if type.rawValue == 14 {
                let nsEvent = NSEvent(cgEvent: event)
                let subtype = Int(nsEvent?.subtype.rawValue ?? -1)
                let data1 = nsEvent?.data1 ?? -1
                let data2 = nsEvent?.data2 ?? -1
                return .systemEvent(subtype: subtype, data1: data1, data2: data2)
            }
            break
        }
        
        return nil
    }
}
