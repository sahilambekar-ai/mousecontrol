import Cocoa
import CoreGraphics
import Combine

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
    
    private init() {}
    
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
    
    /// Starts capturing global mouse events.
    public func start() {
        if isRunning { return }
        
        // Listen to all relevant mouse press, release, and scroll events
        // Ensure 64-bit explicit shift values to prevent type inference overflow issues
        let eventMask = (UInt64(1) << CGEventType.otherMouseDown.rawValue)
                      | (UInt64(1) << CGEventType.otherMouseUp.rawValue)
                      | (UInt64(1) << CGEventType.scrollWheel.rawValue)
                      | (UInt64(1) << CGEventType.leftMouseDown.rawValue)
                      | (UInt64(1) << CGEventType.leftMouseUp.rawValue)
                      | (UInt64(1) << CGEventType.rightMouseDown.rawValue)
                      | (UInt64(1) << CGEventType.rightMouseUp.rawValue)
        
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
    
    /// Processes incoming mouse events.
    /// - Returns: The event to forward to the OS, or nil if the event is swallowed.
    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        // 1. Handle recording mode (recording a trigger in Settings)
        if isRecording {
            if let trigger = detectTrigger(type: type, event: event) {
                // Ensure we only record on the "Down" action to avoid double-firing on release
                if isDownEvent(type: type) {
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
            if let mapping = AppSettings.shared.mappings.first(where: { $0.trigger == trigger && $0.isEnabled }) {
                switch trigger {
                case .button:
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
    
    /// Detects the MouseTrigger enum value from a low-level CGEvent.
    private func detectTrigger(type: CGEventType, event: CGEvent) -> MouseTrigger? {
        switch type {
        case .leftMouseDown, .leftMouseUp:
            return .button(0)
            
        case .rightMouseDown, .rightMouseUp:
            return .button(1)
            
        case .otherMouseDown, .otherMouseUp:
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
