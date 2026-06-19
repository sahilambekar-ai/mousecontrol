import Foundation
import CoreGraphics

public enum ScrollDirection: String, Codable, CaseIterable {
    case up = "Scroll Up"
    case down = "Scroll Down"
    case left = "Scroll Left"
    case right = "Scroll Right"
}

public enum MouseTrigger: Codable, Hashable, Equatable {
    case button(Int)
    case scroll(ScrollDirection)
    case mouseKey(Int) // Key code from mouse keyboard interface
    case systemEvent(subtype: Int, data1: Int, data2: Int) // SystemDefined/NX_SYSDEFINED events
    
    public var displayName: String {
        switch self {
        case .button(let num):
            if num == 0 { return "Left Click (Button 0)" }
            if num == 1 { return "Right Click (Button 1)" }
            if num == 2 { return "Middle Click (Button 2)" }
            return "Mouse Button \(num)"
        case .scroll(let dir):
            return dir.rawValue
        case .mouseKey(let keyCode):
            let name = nameForKeyCode(CGKeyCode(keyCode))
            return "Mouse Key: \(name) (Key \(keyCode))"
        case .systemEvent(let subtype, let data1, let data2):
            if subtype == 7 {
                return "System Mouse Trigger (D1:\(data1) D2:\(data2))"
            } else if subtype == 8 {
                return "System Media Key (D1:\(data1))"
            }
            return "System Event (Subtype:\(subtype) D1:\(data1) D2:\(data2))"
        }
    }
    
    // Coding keys for manual serialization to support heterogeneous enum values easily
    private enum CodingKeys: String, CodingKey {
        case type, buttonNumber, scrollDirection, keyCode, subtype, data1, data2
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "button" {
            let num = try container.decode(Int.self, forKey: .buttonNumber)
            self = .button(num)
        } else if type == "mouseKey" {
            let keyCode = try container.decode(Int.self, forKey: .keyCode)
            self = .mouseKey(keyCode)
        } else if type == "systemEvent" {
            let subtype = try container.decode(Int.self, forKey: .subtype)
            let data1 = try container.decode(Int.self, forKey: .data1)
            let data2 = try container.decode(Int.self, forKey: .data2)
            self = .systemEvent(subtype: subtype, data1: data1, data2: data2)
        } else {
            let dir = try container.decode(ScrollDirection.self, forKey: .scrollDirection)
            self = .scroll(dir)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .button(let num):
            try container.encode("button", forKey: .type)
            try container.encode(num, forKey: .buttonNumber)
        case .scroll(let dir):
            try container.encode("scroll", forKey: .type)
            try container.encode(dir, forKey: .scrollDirection)
        case .mouseKey(let keyCode):
            try container.encode("mouseKey", forKey: .type)
            try container.encode(keyCode, forKey: .keyCode)
        case .systemEvent(let subtype, let data1, let data2):
            try container.encode("systemEvent", forKey: .type)
            try container.encode(subtype, forKey: .subtype)
            try container.encode(data1, forKey: .data1)
            try container.encode(data2, forKey: .data2)
        }
    }
}

public struct ModifierFlags: Codable, Equatable, Hashable {
    public var command: Bool = false
    public var control: Bool = false
    public var option: Bool = false
    public var shift: Bool = false
    
    public init(command: Bool = false, control: Bool = false, option: Bool = false, shift: Bool = false) {
        self.command = command
        self.control = control
        self.option = option
        self.shift = shift
    }
    
    public var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if command { flags.insert(.maskCommand) }
        if control { flags.insert(.maskControl) }
        if option { flags.insert(.maskAlternate) }
        if shift { flags.insert(.maskShift) }
        return flags
    }
    
    public var displayName: String {
        var parts: [String] = []
        if control { parts.append("⌃ Control") }
        if option { parts.append("⌥ Option") }
        if shift { parts.append("⇧ Shift") }
        if command { parts.append("⌘ Command") }
        return parts.joined(separator: " + ")
    }
}

public struct KeyboardShortcut: Codable, Equatable, Hashable {
    public var keyCode: CGKeyCode
    public var modifiers: ModifierFlags
    
    public init(keyCode: CGKeyCode, modifiers: ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    public var displayName: String {
        let keyName = nameForKeyCode(keyCode)
        let mods = modifiers.displayName
        return mods.isEmpty ? keyName : "\(mods) + \(keyName)"
    }
}

public struct MouseMapping: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var trigger: MouseTrigger
    public var shortcut: KeyboardShortcut
    public var isEnabled: Bool
    public var deviceName: String
    
    public init(id: UUID = UUID(), trigger: MouseTrigger, shortcut: KeyboardShortcut, isEnabled: Bool = true, deviceName: String = "All Devices") {
        self.id = id
        self.trigger = trigger
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.deviceName = deviceName
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, trigger, shortcut, isEnabled, deviceName
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.trigger = try container.decode(MouseTrigger.self, forKey: .trigger)
        self.shortcut = try container.decode(KeyboardShortcut.self, forKey: .shortcut)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName) ?? "All Devices"
    }
}

// Available standard macOS virtual keycodes mapping
public struct KeyDefinition: Identifiable, Hashable {
    public var id: CGKeyCode { keyCode }
    public let keyCode: CGKeyCode
    public let name: String
}

public let availableKeys: [KeyDefinition] = [
    KeyDefinition(keyCode: 123, name: "Left Arrow"),
    KeyDefinition(keyCode: 124, name: "Right Arrow"),
    KeyDefinition(keyCode: 125, name: "Down Arrow"),
    KeyDefinition(keyCode: 126, name: "Up Arrow"),
    KeyDefinition(keyCode: 49, name: "Space"),
    KeyDefinition(keyCode: 36, name: "Return"),
    KeyDefinition(keyCode: 48, name: "Tab"),
    KeyDefinition(keyCode: 53, name: "Escape"),
    KeyDefinition(keyCode: 51, name: "Backspace"),
    KeyDefinition(keyCode: 117, name: "Delete"),
    KeyDefinition(keyCode: 116, name: "Page Up"),
    KeyDefinition(keyCode: 121, name: "Page Down"),
    KeyDefinition(keyCode: 115, name: "Home"),
    KeyDefinition(keyCode: 119, name: "End"),
    
    // Letters
    KeyDefinition(keyCode: 0, name: "A"),
    KeyDefinition(keyCode: 11, name: "B"),
    KeyDefinition(keyCode: 8, name: "C"),
    KeyDefinition(keyCode: 2, name: "D"),
    KeyDefinition(keyCode: 14, name: "E"),
    KeyDefinition(keyCode: 3, name: "F"),
    KeyDefinition(keyCode: 5, name: "G"),
    KeyDefinition(keyCode: 4, name: "H"),
    KeyDefinition(keyCode: 34, name: "I"),
    KeyDefinition(keyCode: 38, name: "J"),
    KeyDefinition(keyCode: 40, name: "K"),
    KeyDefinition(keyCode: 37, name: "L"),
    KeyDefinition(keyCode: 46, name: "M"),
    KeyDefinition(keyCode: 45, name: "N"),
    KeyDefinition(keyCode: 31, name: "O"),
    KeyDefinition(keyCode: 35, name: "P"),
    KeyDefinition(keyCode: 12, name: "Q"),
    KeyDefinition(keyCode: 15, name: "R"),
    KeyDefinition(keyCode: 1, name: "S"),
    KeyDefinition(keyCode: 17, name: "T"),
    KeyDefinition(keyCode: 32, name: "U"),
    KeyDefinition(keyCode: 9, name: "V"),
    KeyDefinition(keyCode: 13, name: "W"),
    KeyDefinition(keyCode: 7, name: "X"),
    KeyDefinition(keyCode: 16, name: "Y"),
    KeyDefinition(keyCode: 6, name: "Z"),
    
    // Numbers
    KeyDefinition(keyCode: 18, name: "1"),
    KeyDefinition(keyCode: 19, name: "2"),
    KeyDefinition(keyCode: 20, name: "3"),
    KeyDefinition(keyCode: 21, name: "4"),
    KeyDefinition(keyCode: 23, name: "5"),
    KeyDefinition(keyCode: 22, name: "6"),
    KeyDefinition(keyCode: 26, name: "7"),
    KeyDefinition(keyCode: 28, name: "8"),
    KeyDefinition(keyCode: 25, name: "9"),
    KeyDefinition(keyCode: 29, name: "0"),
    
    // Function keys
    KeyDefinition(keyCode: 122, name: "F1"),
    KeyDefinition(keyCode: 120, name: "F2"),
    KeyDefinition(keyCode: 99, name: "F3"),
    KeyDefinition(keyCode: 118, name: "F4"),
    KeyDefinition(keyCode: 96, name: "F5"),
    KeyDefinition(keyCode: 97, name: "F6"),
    KeyDefinition(keyCode: 98, name: "F7"),
    KeyDefinition(keyCode: 100, name: "F8"),
    KeyDefinition(keyCode: 101, name: "F9"),
    KeyDefinition(keyCode: 109, name: "F10"),
    KeyDefinition(keyCode: 103, name: "F11"),
    KeyDefinition(keyCode: 111, name: "F12"),
    
    // Special Virtual Actions
    KeyDefinition(keyCode: 2000, name: "Scroll Up"),
    KeyDefinition(keyCode: 2001, name: "Scroll Down"),
    KeyDefinition(keyCode: 2002, name: "Scroll Left"),
    KeyDefinition(keyCode: 2003, name: "Scroll Right"),
    KeyDefinition(keyCode: 2004, name: "Scroll (Drag Mouse)")
]

public func nameForKeyCode(_ code: CGKeyCode) -> String {
    return availableKeys.first(where: { $0.keyCode == code })?.name ?? "Key \(code)"
}
