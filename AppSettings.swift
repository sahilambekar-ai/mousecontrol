import Foundation
import Cocoa
import Combine

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private let mappingsKey = "com.sahil.MouseControl.mappings"
    private let enabledKey = "com.sahil.MouseControl.isEnabled"
    private let stageManagerToggleKey = "com.sahil.MouseControl.toggleStageManagerOnShowDesktop"
    private let missionControlToggleKey = "com.sahil.MouseControl.toggleMissionControlOnShowDesktop"
    private let themeKey = "com.sahil.MouseControl.themeMode"
    private let activeProfileKey = "com.sahil.MouseControl.activeProfile"
    private let profilesKey = "com.sahil.MouseControl.profiles"
    
    @Published public var activeProfile: String = "Default" {
        didSet {
            UserDefaults.standard.set(activeProfile, forKey: activeProfileKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published public var profiles: [String] = ["Default"] {
        didSet {
            UserDefaults.standard.set(profiles, forKey: profilesKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    // Path to Application Support config file for force-quit resiliency
    private var configFilePath: URL? {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDir = appSupportURL.appendingPathComponent("MouseControl", isDirectory: true)
        
        // Ensure the directory exists
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        return appDir.appendingPathComponent("config.json")
    }
    
    @Published public var mappings: [MouseMapping] = [] {
        didSet {
            saveMappings()
        }
    }
    
    @Published public var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            UserDefaults.standard.synchronize() // Force flush cache immediately
        }
    }
    
    @Published public var toggleStageManagerOnShowDesktop: Bool = false {
        didSet {
            UserDefaults.standard.set(toggleStageManagerOnShowDesktop, forKey: stageManagerToggleKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published public var toggleMissionControlOnShowDesktop: Bool = false {
        didSet {
            UserDefaults.standard.set(toggleMissionControlOnShowDesktop, forKey: missionControlToggleKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Theme mode: "system", "light", or "dark"
    @Published public var themeMode: String = "system" {
        didSet {
            UserDefaults.standard.set(themeMode, forKey: themeKey)
            UserDefaults.standard.synchronize()
            applyTheme()
        }
    }
    
    /// Applies the current theme to the entire application
    public func applyTheme() {
        DispatchQueue.main.async {
            switch self.themeMode {
            case "light":
                NSApp.appearance = NSAppearance(named: .aqua)
            case "dark":
                NSApp.appearance = NSAppearance(named: .darkAqua)
            default:
                NSApp.appearance = nil // Follow system
            }
        }
    }
    
    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        self.toggleStageManagerOnShowDesktop = UserDefaults.standard.bool(forKey: stageManagerToggleKey)
        self.toggleMissionControlOnShowDesktop = UserDefaults.standard.bool(forKey: missionControlToggleKey)
        self.themeMode = UserDefaults.standard.string(forKey: themeKey) ?? "system"
        self.activeProfile = UserDefaults.standard.string(forKey: activeProfileKey) ?? "Default"
        self.profiles = UserDefaults.standard.stringArray(forKey: profilesKey) ?? ["Default"]
        loadMappings()
        
        // Populate default mappings if empty on first run
        if mappings.isEmpty {
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
        }
    }
    
    private func loadMappings() {
        // 1. Try loading from permanent Application Support config first (immune to force-quits)
        if let configURL = configFilePath, FileManager.default.fileExists(atPath: configURL.path) {
            do {
                let data = try Data(contentsOf: configURL)
                let decoded = try JSONDecoder().decode([MouseMapping].self, from: data)
                self.mappings = decoded
                print("[AppSettings] Successfully loaded mappings from Application Support config file.")
                return
            } catch {
                print("[AppSettings] Application Support config load failed, falling back to UserDefaults: \(error)")
            }
        }
        
        // 2. Fallback to UserDefaults
        guard let data = UserDefaults.standard.data(forKey: mappingsKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([MouseMapping].self, from: data)
            self.mappings = decoded
            print("[AppSettings] Loaded mappings from UserDefaults.")
        } catch {
            print("[AppSettings] Failed to load mappings from UserDefaults: \(error)")
        }
    }
    
    private func saveMappings() {
        // 1. Save to UserDefaults and sync cache
        do {
            let data = try JSONEncoder().encode(mappings)
            UserDefaults.standard.set(data, forKey: mappingsKey)
            UserDefaults.standard.synchronize() // Force synchronization to system prefs
        } catch {
            print("[AppSettings] Failed to save mappings to UserDefaults: \(error)")
        }
        
        // 2. Atomic write to disk backup
        guard let configURL = configFilePath else { return }
        do {
            let data = try JSONEncoder().encode(mappings)
            // .atomic write creates a temporary file first and replaces it in one filesystem tick
            try data.write(to: configURL, options: .atomic)
            print("[AppSettings] Atomic file-write successfully completed at: \(configURL.path)")
        } catch {
            print("[AppSettings] Failed to write config file to Application Support: \(error)")
        }
    }
}
