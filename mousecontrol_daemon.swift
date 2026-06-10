import Foundation
import CoreGraphics
import Network
import IOKit
import IOKit.hid
import ApplicationServices

// MARK: - Models

public enum ScrollDirection: String, Codable, CaseIterable {
    case up = "Scroll Up"
    case down = "Scroll Down"
    case left = "Scroll Left"
    case right = "Scroll Right"
}

public enum MouseTrigger: Codable, Hashable, Equatable {
    case button(Int)
    case scroll(ScrollDirection)
    
    private enum CodingKeys: String, CodingKey {
        case type, buttonNumber, scrollDirection
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "button" {
            let num = try container.decode(Int.self, forKey: .buttonNumber)
            self = .button(num)
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
}

public struct KeyboardShortcut: Codable, Equatable, Hashable {
    public var keyCode: CGKeyCode
    public var modifiers: ModifierFlags
    
    public init(keyCode: CGKeyCode, modifiers: ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
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
public struct KeyDefinition {
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
    KeyDefinition(keyCode: 111, name: "F12")
]

public func nameForKeyCode(_ code: CGKeyCode) -> String {
    return availableKeys.first(where: { $0.keyCode == code })?.name ?? "Key \(code)"
}

// MARK: - Key Simulator

public final class KeySimulator {
    public static let shared = KeySimulator()
    private init() {}
    
    public func simulateShortcut(keyCode: CGKeyCode, modifiers: ModifierFlags, isDown: Bool) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { return }
        
        var flags = event.flags
        if modifiers.command { flags.insert(.maskCommand) } else { flags.remove(.maskCommand) }
        if modifiers.control { flags.insert(.maskControl) } else { flags.remove(.maskControl) }
        if modifiers.option { flags.insert(.maskAlternate) } else { flags.remove(.maskAlternate) }
        if modifiers.shift { flags.insert(.maskShift) } else { flags.remove(.maskShift) }
        event.flags = flags
        
        event.post(tap: .cgSessionEventTap)
    }
    
    public func simulateTap(keyCode: CGKeyCode, modifiers: ModifierFlags) {
        simulateShortcut(keyCode: keyCode, modifiers: modifiers, isDown: true)
        usleep(10000) // 10ms
        simulateShortcut(keyCode: keyCode, modifiers: modifiers, isDown: false)
    }
}

// MARK: - Configuration Manager

public final class DaemonConfig: Codable {
    public static let shared = DaemonConfig()
    
    public var mappings: [MouseMapping] = []
    public var isEnabled: Bool = true
    
    private init() {
        load()
        if mappings.isEmpty {
            // Default mappings
            mappings = [
                MouseMapping(
                    trigger: .button(4),
                    shortcut: KeyboardShortcut(keyCode: 123, modifiers: ModifierFlags(control: true)),
                    isEnabled: true,
                    deviceName: "All Devices"
                ),
                MouseMapping(
                    trigger: .button(5),
                    shortcut: KeyboardShortcut(keyCode: 124, modifiers: ModifierFlags(control: true)),
                    isEnabled: true,
                    deviceName: "All Devices"
                )
            ]
            save()
        }
    }
    
    private var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".mousecontrol.json", isDirectory: false)
    }
    
    public func load() {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return }
        do {
            let data = try Data(contentsOf: configURL)
            let decoded = try JSONDecoder().decode(DaemonConfig.self, from: data)
            self.mappings = decoded.mappings
            self.isEnabled = decoded.isEnabled
            print("[Config] Configuration loaded from \(configURL.path)")
        } catch {
            print("[Config] Failed to load configuration: \(error)")
        }
    }
    
    public func save() {
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: configURL, options: .atomic)
            print("[Config] Configuration saved to \(configURL.path)")
        } catch {
            print("[Config] Failed to save configuration: \(error)")
        }
    }
}

// MARK: - Event Tap Callback & Manager

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }
    
    let manager = Unmanaged<DaemonEventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        print("[EventTap] Event tap disabled by OS. Re-enabling...")
        if let tap = manager.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return nil
    }
    
    if let processedEvent = manager.handleEvent(type: type, event: event) {
        return Unmanaged.passUnretained(processedEvent)
    } else {
        return nil // Swallow event
    }
}

public final class DaemonEventTapManager {
    public static let shared = DaemonEventTapManager()
    
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hidManager: IOHIDManager?
    
    // Live Diagnostics (Shared with HTTP server)
    public var lastActiveDeviceName: String = "All Devices"
    public var lastActiveTrigger: MouseTrigger? = nil
    public var lastActiveKeyEvent: String = "None"
    public var connectedMice: [String] = ["All Devices"]
    
    private init() {
        setupHIDManager()
    }
    
    public func start() {
        if eventTap != nil { return }
        
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
        
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: selfPointer
        ) else {
            print("[EventTap] ERROR: Failed to create CGEventTap. Please verify Accessibility permissions in System Settings > Privacy & Security > Accessibility for the Terminal running this script.")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[EventTap] Event tap installed and running.")
    }
    
    public func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        self.eventTap = nil
        self.runLoopSource = nil
        print("[EventTap] Event tap stopped.")
    }
    
    private func setupHIDManager() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.hidManager = manager
        
        IOHIDManagerSetDeviceMatching(manager, nil)
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { (context, result, sender, device) in
            guard let context = context else { return }
            let this = Unmanaged<DaemonEventTapManager>.fromOpaque(context).takeUnretainedValue()
            this.updateConnectedMice()
        }, selfPointer)
        
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { (context, result, sender, device) in
            guard let context = context else { return }
            let this = Unmanaged<DaemonEventTapManager>.fromOpaque(context).takeUnretainedValue()
            this.updateConnectedMice()
        }, selfPointer)
        
        IOHIDManagerRegisterInputValueCallback(manager, { (context, result, sender, value) in
            guard let sender = sender, let context = context else { return }
            let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
            if let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
                let this = Unmanaged<DaemonEventTapManager>.fromOpaque(context).takeUnretainedValue()
                this.lastActiveDeviceName = name
            }
        }, selfPointer)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            print("[HIDManager] Failed to open: \(openResult)")
        }
        updateConnectedMice()
    }
    
    private func updateConnectedMice() {
        guard let manager = hidManager else { return }
        var miceNames: [String] = ["All Devices"]
        
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
                }
            }
        }
        self.connectedMice = miceNames
    }
    
    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        // Log key presses/releases
        if type == .keyDown || type == .keyUp {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            self.lastActiveKeyEvent = "Key \(type == .keyDown ? "Down" : "Up"): \(keyCode) (\(nameForKeyCode(CGKeyCode(keyCode))))"
            return event
        }
        
        if type == .flagsChanged {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            self.lastActiveKeyEvent = "FlagsChanged Key: \(keyCode) (\(nameForKeyCode(CGKeyCode(keyCode)))) Flags: \(flags.rawValue)"
            return event
        }
        
        // If engine is disabled globally, let events flow
        guard DaemonConfig.shared.isEnabled else {
            return event
        }
        
        if let trigger = detectTrigger(type: type, event: event) {
            self.lastActiveTrigger = trigger
            
            let activeDevice = self.lastActiveDeviceName
            if let mapping = DaemonConfig.shared.mappings.first(where: { 
                $0.trigger == trigger && 
                $0.isEnabled && 
                ($0.deviceName == "All Devices" || $0.deviceName == activeDevice)
            }) {
                switch trigger {
                case .button:
                    if type == .otherMouseDragged || type == .leftMouseDragged || type == .rightMouseDragged {
                        return nil // Swallow drag for mapped button
                    }
                    let isDown = (type == .otherMouseDown || type == .leftMouseDown || type == .rightMouseDown)
                    KeySimulator.shared.simulateShortcut(
                        keyCode: mapping.shortcut.keyCode,
                        modifiers: mapping.shortcut.modifiers,
                        isDown: isDown
                    )
                    return nil // Swallow mouse click
                    
                case .scroll:
                    // Simulate quick tap for scrolls
                    KeySimulator.shared.simulateTap(
                        keyCode: mapping.shortcut.keyCode,
                        modifiers: mapping.shortcut.modifiers
                    )
                    return nil // Swallow scroll axis notch
                }
            }
        }
        
        return event
    }
    
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
            if deltaY > 0 { return .scroll(.up) }
            if deltaY < 0 { return .scroll(.down) }
            if deltaX > 0 { return .scroll(.left) }
            if deltaX < 0 { return .scroll(.right) }
            
        default:
            break
        }
        return nil
    }
}

// MARK: - HTTPServer (NWListener based)

class DaemonHTTPServer {
    let port: UInt16
    let listener: NWListener
    let webRoot: URL
    
    init(port: UInt16) throws {
        self.port = port
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.webRoot = home.appendingPathComponent(".mousecontrol/web", isDirectory: true)
        
        let parameters = NWParameters.tcp
        self.listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
    }
    
    func start() {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        listener.start(queue: .main)
        print("[HTTP] Server listening on http://localhost:\(port)")
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        receiveData(connection: connection)
    }
    
    private func receiveData(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                self.processRequest(connection: connection, data: data)
            }
            if error != nil || isComplete {
                connection.cancel()
            }
        }
    }
    
    private func processRequest(connection: NWConnection, data: Data) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, statusText: "Bad Request", contentType: "text/plain", body: "Invalid UTF-8".data(using: .utf8)!)
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return }
        
        let parts = lines[0].components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, statusText: "Bad Request", contentType: "text/plain", body: "Invalid request line".data(using: .utf8)!)
            return
        }
        
        let method = parts[0]
        let path = parts[1].components(separatedBy: "?")[0]
        
        // Options CORS support
        if method == "OPTIONS" {
            sendCORSPreflight(connection: connection)
            return
        }
        
        // MARK: API Routes
        
        if path == "/api/status" && method == "GET" {
            let status = getStatusJSON()
            sendResponse(connection: connection, statusCode: 200, statusText: "OK", contentType: "application/json", body: status)
            return
        }
        
        if path == "/api/config" && method == "POST" {
            if let bodyData = extractBody(requestString: requestString, data: data) {
                do {
                    let newMappings = try JSONDecoder().decode([MouseMapping].self, from: bodyData)
                    DaemonConfig.shared.mappings = newMappings
                    DaemonConfig.shared.save()
                    sendResponse(connection: connection, statusCode: 200, statusText: "OK", contentType: "application/json", body: "{\"success\":true}".data(using: .utf8)!)
                } catch {
                    print("[HTTP] Config decode error: \(error)")
                    sendResponse(connection: connection, statusCode: 400, statusText: "Bad Request", contentType: "application/json", body: "{\"success\":false,\"error\":\"JSON parse failure\"}".data(using: .utf8)!)
                }
            } else {
                sendResponse(connection: connection, statusCode: 400, statusText: "Bad Request", contentType: "text/plain", body: "Missing Body".data(using: .utf8)!)
            }
            return
        }
        
        if path == "/api/toggle" && method == "POST" {
            DaemonConfig.shared.isEnabled.toggle()
            DaemonConfig.shared.save()
            
            // Sync with event tap manager state
            if DaemonConfig.shared.isEnabled {
                DaemonEventTapManager.shared.start()
            } else {
                DaemonEventTapManager.shared.stop()
            }
            
            let status = "{\"success\":true,\"isEnabled\":\(DaemonConfig.shared.isEnabled)}"
            sendResponse(connection: connection, statusCode: 200, statusText: "OK", contentType: "application/json", body: status.data(using: .utf8)!)
            return
        }
        
        // MARK: Static File Serving
        
        let fileMap: [String: (file: String, type: String)] = [
            "/": ("index.html", "text/html"),
            "/index.html": ("index.html", "text/html"),
            "/style.css": ("style.css", "text/css"),
            "/app.js": ("app.js", "application/javascript")
        ]
        
        let requestFile = fileMap[path]
        
        // Special case: serve the local install.sh installer script itself if requested!
        if path == "/install.sh" {
            let installURL = webRoot.deletingLastPathComponent().appendingPathComponent("install.sh")
            if let scriptData = try? Data(contentsOf: installURL) {
                sendResponse(connection: connection, statusCode: 200, statusText: "OK", contentType: "text/plain", body: scriptData)
                return
            }
        }
        
        if let mapping = requestFile {
            let fileURL = webRoot.appendingPathComponent(mapping.file)
            if let fileData = try? Data(contentsOf: fileURL) {
                sendResponse(connection: connection, statusCode: 200, statusText: "OK", contentType: mapping.type, body: fileData)
            } else {
                sendResponse(connection: connection, statusCode: 404, statusText: "Not Found", contentType: "text/plain", body: "Web interface assets not found. Run installer to copy assets.".data(using: .utf8)!)
            }
        } else {
            sendResponse(connection: connection, statusCode: 404, statusText: "Not Found", contentType: "text/plain", body: "Not Found".data(using: .utf8)!)
        }
    }
    
    private func extractBody(requestString: String, data: Data) -> Data? {
        guard let range = requestString.range(of: "\r\n\r\n") else { return nil }
        let headerLength = requestString.distance(from: requestString.startIndex, to: range.upperBound)
        guard data.count > headerLength else { return nil }
        return data.subdata(in: headerLength..<data.count)
    }
    
    private func getStatusJSON() -> Data {
        let et = DaemonEventTapManager.shared
        
        struct StatusResponse: Codable {
            let isEnabled: Bool
            let lastActiveDevice: String
            let lastActiveTrigger: MouseTrigger?
            let lastActiveKey: String
            let connectedMice: [String]
            let mappings: [MouseMapping]
        }
        
        let response = StatusResponse(
            isEnabled: DaemonConfig.shared.isEnabled,
            lastActiveDevice: et.lastActiveDeviceName,
            lastActiveTrigger: et.lastActiveTrigger,
            lastActiveKey: et.lastActiveKeyEvent,
            connectedMice: et.connectedMice,
            mappings: DaemonConfig.shared.mappings
        )
        
        do {
            return try JSONEncoder().encode(response)
        } catch {
            return "{}".data(using: .utf8)!
        }
    }
    
    private func sendCORSPreflight(connection: NWConnection) {
        var response = "HTTP/1.1 204 No Content\r\n"
        response += "Access-Control-Allow-Origin: *\r\n"
        response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        response += "Access-Control-Allow-Headers: Content-Type\r\n"
        response += "Connection: close\r\n\r\n"
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, statusText: String, contentType: String, body: Data) {
        var headers = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        headers += "Content-Type: \(contentType)\r\n"
        headers += "Content-Length: \(body.count)\r\n"
        headers += "Access-Control-Allow-Origin: *\r\n"
        headers += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        headers += "Access-Control-Allow-Headers: Content-Type\r\n"
        headers += "Connection: close\r\n\r\n"
        
        guard let headerData = headers.data(using: .utf8) else {
            connection.cancel()
            return
        }
        
        var responseData = Data()
        responseData.append(headerData)
        responseData.append(body)
        
        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
}

// MARK: - Entry Point

print("=== MouseControl Daemon Starting ===")

// 1. Check Accessibility permissions
let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

if !isTrusted {
    print("[Warning] Accessibility permissions are missing. A system prompt should appear shortly requesting access.")
    print("[Warning] You must grant access to Terminal (or whichever app runs this daemon) in System Settings.")
}

// 2. Initialize Event Tap (if enabled)
if DaemonConfig.shared.isEnabled {
    DaemonEventTapManager.shared.start()
}

// 3. Start HTTP server on port 9002
do {
    let server = try DaemonHTTPServer(port: 9002)
    server.start()
} catch {
    print("[HTTP] ERROR: Failed to start HTTP server on port 9002: \(error)")
    exit(1)
}

// 4. Run loop
print("[Daemon] Core loop entering CFRunLoop...")
CFRunLoopRun()
