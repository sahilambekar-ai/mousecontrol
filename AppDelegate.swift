import Cocoa
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Establish system status bar item
        setupMenuBar()
        
        // Check permissions and initialize
        checkAndInitialize()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        // Attempt to load standard SF Symbol for mouse
        if let image = NSImage(systemSymbolName: "mouse", accessibilityDescription: "MouseControl") {
            image.isTemplate = true // Automatically adapts to Light/Dark menu bar styles!
            button.image = image
        } else {
            // Fallback to emoji character if system Symbol fails
            button.title = "🖱️"
        }
        
        rebuildMenu()
    }
    
    public func rebuildMenu() {
        let menu = NSMenu()
        
        // App Identity Label
        let titleItem = NSMenuItem(title: "MouseControl v1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings Action
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Enabled Toggle
        let toggleItem = NSMenuItem(
            title: AppSettings.shared.isEnabled ? "Remapping: Active" : "Remapping: Paused",
            action: #selector(toggleRemapping),
            keyEquivalent: "e"
        )
        toggleItem.target = self
        toggleItem.state = AppSettings.shared.isEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit Application Action
        let quitItem = NSMenuItem(title: "Quit MouseControl", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    private func checkAndInitialize() {
        if AXIsProcessTrusted() {
            print("[AppDelegate] Process has accessibility access trust. Starting event tap.")
            EventTapManager.shared.start()
        } else {
            print("[AppDelegate] Process does not have accessibility access. Directing user to Settings dashboard.")
            // Open main settings dashboard immediately so user sees the embedded red warning banner
            showSettings()
        }
    }
    
    @objc private func toggleRemapping() {
        AppSettings.shared.isEnabled.toggle()
        rebuildMenu()
        
        if AppSettings.shared.isEnabled {
            EventTapManager.shared.start()
        } else {
            EventTapManager.shared.stop()
        }
    }
    
    @objc public func showSettings() {
        // Reuse current settings window if active
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create custom hosting controller enclosing SwiftUI dashboard
        let contentView = SettingsView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "MouseControl Settings"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        print("[AppDelegate] Shutting down event listeners and terminating application.")
        EventTapManager.shared.stop()
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == settingsWindow {
            settingsWindow = nil
        }
    }
}
