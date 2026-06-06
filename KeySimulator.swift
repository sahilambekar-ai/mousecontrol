import Foundation
import CoreGraphics

public final class KeySimulator {
    public static let shared = KeySimulator()
    
    private init() {}
    
    /// Simulates a virtual key press or release globally on macOS.
    /// - Parameters:
    ///   - keyCode: The CGKeyCode representing the key (e.g. 124 for Right Arrow)
    ///   - modifiers: The ModifierFlags containing command, control, option, shift states.
    ///   - isDown: True for key press down, False for key release up.
    public func simulateShortcut(keyCode: CGKeyCode, modifiers: ModifierFlags, isDown: Bool) {
        // We use combinedSessionState to simulate events on behalf of the active user session
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            print("[KeySimulator] Error: Failed to create CGEventSource")
            return
        }
        
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else {
            print("[KeySimulator] Error: Failed to create CGEvent for keyCode: \(keyCode), isDown: \(isDown)")
            return
        }
        
        // Merge modifier flags to preserve essential default system flags
        var flags = event.flags
        if modifiers.command { flags.insert(.maskCommand) } else { flags.remove(.maskCommand) }
        if modifiers.control { flags.insert(.maskControl) } else { flags.remove(.maskControl) }
        if modifiers.option { flags.insert(.maskAlternate) } else { flags.remove(.maskAlternate) }
        if modifiers.shift { flags.insert(.maskShift) } else { flags.remove(.maskShift) }
        event.flags = flags
        
        // Post the event into the session event stream so macOS system hotkeys (like spaces / Mission Control) capture it
        event.post(tap: .cgSessionEventTap)
    }
    
    /// Simulates a rapid key tap (down then up) for events that don't support continuous press-and-hold (e.g. Scroll wheel remappings)
    public func simulateTap(keyCode: CGKeyCode, modifiers: ModifierFlags) {
        simulateShortcut(keyCode: keyCode, modifiers: modifiers, isDown: true)
        
        // Small delay to ensure the OS registers the down state before the up state
        usleep(10000) // 10ms
        
        simulateShortcut(keyCode: keyCode, modifiers: modifiers, isDown: false)
    }
}
