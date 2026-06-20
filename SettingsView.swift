import SwiftUI
import CoreGraphics
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var tapManager = EventTapManager.shared
    
    // UI state
    @State private var selectedTab = "Buttons"
    @State private var selectedDevice = "All Devices"
    @State private var newProfileName = ""
    @State private var showingCaptureSheet = false
    
    // UI state for adding a new mapping
    @State private var showingAddSheet = false
    @State private var recordingTrigger: MouseTrigger? = nil
    @State private var isRecording = false
    @State private var selectedKeyCode: CGKeyCode = 124 // Right arrow default
    @State private var modifierCommand = false
    @State private var modifierControl = false
    @State private var modifierOption = false
    @State private var modifierShift = false
    
    // Autostart state
    @State private var startAtLogin = false
    
    // System Permission status & active polling timer
    @State private var isTrusted = false
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // Modifiers tracking
    @State private var pressedModifiers: NSEvent.ModifierFlags = []
    
    // Flash effect for recently pressed hardware buttons
    @State private var highlightedTrigger: MouseTrigger? = nil
    
    let tabs = ["Buttons", "Wheel", "Chords", "Profiles", "Cursor", "Device", "HID Inspector", "License & Support"]
    
    public init() {}
    
    // Load local mouse icon PNG resource
    private func loadMouseIcon() -> NSImage? {
        if let path = Bundle.main.path(forResource: "mouse_icon", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. TOP HEADER BAR
            HStack(spacing: 12) {
                // Remapping Master Toggle (ON/OFF Button)
                Button(action: {
                    settings.isEnabled.toggle()
                    if settings.isEnabled {
                        tapManager.start()
                    } else {
                        tapManager.stop()
                    }
                    AppDelegate().rebuildMenu()
                }) {
                    Text(settings.isEnabled ? "ON" : "OFF")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(settings.isEnabled ? .white : .primary)
                        .frame(width: 44, height: 22)
                        .background(settings.isEnabled ? Color.blue : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                // Profile Selector Dropdown
                Picker("", selection: $settings.activeProfile) {
                    ForEach(settings.profiles, id: \.self) { profile in
                        Text(profile).tag(profile)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 120)
                
                Spacer()
                
                // Theme Mode Toggle Button
                Button(action: {
                    switch settings.themeMode {
                    case "system":
                        settings.themeMode = "light"
                    case "light":
                        settings.themeMode = "dark"
                    default:
                        settings.themeMode = "system"
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: settings.themeMode == "dark" ? "moon.fill" : settings.themeMode == "light" ? "sun.max.fill" : "display")
                            .font(.system(size: 11))
                        Text(settings.themeMode == "dark" ? "Dark" : settings.themeMode == "light" ? "Light" : "Auto")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(settings.themeMode == "dark" ? .purple : settings.themeMode == "light" ? .orange : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(settings.themeMode == "dark" ? Color.purple.opacity(0.15) : settings.themeMode == "light" ? Color.orange.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Cycle theme: System → Light → Dark")
                
                // Capture Tool Button
                Button(action: {
                    showingCaptureSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 11))
                        Text("Capture Clicks")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Open Mouse Click Capture Tool")
                
                // Connection Status & Active Mouse Dropdown
                HStack(spacing: 6) {
                    Circle()
                        .fill(tapManager.connectedMice.count > 1 ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Picker("", selection: $selectedDevice) {
                        ForEach(tapManager.connectedMice, id: \.self) { device in
                            Text(device).tag(device)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 180)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 2. TAB MENU BAR
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        Button(action: {
                            selectedTab = tab
                        }) {
                            VStack(spacing: 0) {
                                Text(tab)
                                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                                    .foregroundColor(selectedTab == tab ? .blue : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                
                                // Tab Highlight Line
                                Rectangle()
                                    .fill(selectedTab == tab ? Color.blue : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 3. ACCESSIBILITY / ERROR WARNING BANNERS
            if !isTrusted {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Permission Required")
                            .font(.system(size: 12, weight: .semibold))
                        Text("To intercept hardware mouse clicks and trigger keyboard shortcuts in the background, macOS requires system Accessibility privileges.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Authorize") {
                        openAccessibilitySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)
                .padding(.horizontal)
                .padding(.top, 8)
            } else if tapManager.hasFailedToStart {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("macOS Accessibility Cache Error")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Keyboard remapping engine is currently blocked by macOS. Please toggle the MouseControl switch OFF and ON in Settings > Privacy & Security > Accessibility.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Fix...") {
                        openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            // 4. MAIN PANEL AREA (SPLIT SCREEN)
            HStack(spacing: 0) {
                // LEFT COLUMN: Configurations / Lists
                VStack(spacing: 0) {
                    if selectedTab == "Buttons" || selectedTab == "Wheel" {
                        ScrollView {
                            VStack(spacing: 8) {
                                let listMappings = settings.mappings.filter { mapping in
                                    let matchesProfile = (mapping.profileName == settings.activeProfile)
                                    guard matchesProfile else { return false }
                                    
                                    let matchesDevice = (selectedDevice == "All Devices" || mapping.deviceName == selectedDevice)
                                    if selectedTab == "Buttons" {
                                        switch mapping.trigger {
                                        case .button, .mouseKey, .systemEvent:
                                            return matchesDevice
                                        default:
                                            return false
                                        }
                                    } else {
                                        if case .scroll = mapping.trigger { return matchesDevice }
                                    }
                                    return false
                                }
                                
                                if listMappings.isEmpty {
                                    VStack(spacing: 12) {
                                        Spacer()
                                        Image(systemName: selectedTab == "Buttons" ? "mouse" : "arrow.up.and.down.circle")
                                            .font(.system(size: 36))
                                            .foregroundColor(.secondary.opacity(0.5))
                                        
                                        Text("No \(selectedTab) Mappings")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        
                                        Text("Add a shortcut macro for your physical mouse inputs.")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 24)
                                        Spacer()
                                    }
                                    .frame(minHeight: 220)
                                } else {
                                    ForEach(listMappings) { mapping in
                                        HStack(spacing: 10) {
                                            // Mapping Enabled Switch
                                            Toggle("", isOn: Binding(
                                                get: { mapping.isEnabled },
                                                set: { newValue in
                                                    if let idx = settings.mappings.firstIndex(where: { $0.id == mapping.id }) {
                                                        settings.mappings[idx].isEnabled = newValue
                                                    }
                                                }
                                            ))
                                            .toggleStyle(.checkbox)
                                            .labelsHidden()
                                            
                                            // Mapping Trigger & Key Display
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(mapping.trigger.displayName)
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                                    .foregroundColor(mapping.isEnabled ? .primary : .secondary)
                                                
                                                Text(mapping.shortcut.displayName)
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundColor(.blue)
                                            }
                                            
                                            Spacer()
                                            
                                            // Delete Button
                                            Button(action: {
                                                settings.mappings.removeAll(where: { $0.id == mapping.id })
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red.opacity(0.8))
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(highlightedTrigger == mapping.trigger ? Color.blue.opacity(0.15) : Color(NSColor.textBackgroundColor))
                                                .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                                        )
                                    }
                                }
                            }
                            .padding(12)
                        }
                        
                        Divider()
                        
                        // Footer Operations (Add Mapping Button and Toggle)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Show Desktop ➡️ Mission Control", isOn: $settings.toggleMissionControlOnShowDesktop)
                                    .toggleStyle(.checkbox)
                                    .font(.system(size: 10))
                            }
                            .padding(.leading, 12)
                            .padding(.vertical, 4)
                            
                            Spacer()
                            
                            Button(action: {
                                resetForm()
                                showingAddSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Add Mapping")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .padding(10)
                        }
                        
                    } else if selectedTab == "Chords" {
                        VStack(spacing: 16) {
                            Image(systemName: "square.grid.3x2.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Chords Mapping")
                                .font(.headline)
                            Text("Map combinations of multiple mouse buttons clicked simultaneously to execute custom system workflows.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        
                    } else if selectedTab == "Profiles" {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Profile Management")
                                .font(.headline)
                            
                            HStack(spacing: 12) {
                                TextField("New Profile Name", text: $newProfileName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 200)
                                
                                Button("Create Profile") {
                                    let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty && !settings.profiles.contains(trimmed) {
                                        settings.profiles.append(trimmed)
                                        newProfileName = ""
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            
                            Text("Profiles List:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(settings.profiles, id: \.self) { profile in
                                        HStack {
                                            HStack(spacing: 6) {
                                                Image(systemName: settings.activeProfile == profile ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(settings.activeProfile == profile ? .green : .secondary)
                                                Text(profile)
                                                    .fontWeight(settings.activeProfile == profile ? .bold : .regular)
                                            }
                                            
                                            Spacer()
                                            
                                            if profile != "Default" {
                                                Button(action: {
                                                    // Delete profile and remove all mappings mapped to it
                                                    settings.profiles.removeAll(where: { $0 == profile })
                                                    settings.mappings.removeAll(where: { $0.profileName == profile })
                                                    if settings.activeProfile == profile {
                                                        settings.activeProfile = "Default"
                                                    }
                                                }) {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.red)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(10)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(6)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            settings.activeProfile = profile
                                        }
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    } else if selectedTab == "Cursor" {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Cursor Movement Settings")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Tracking Speed")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Slider(value: .constant(0.6), in: 0...1)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Scrolling Acceleration")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Slider(value: .constant(0.4), in: 0...1)
                            }
                            
                            Toggle("Smart Zoom (Double Click Scroll Wheel)", isOn: .constant(true))
                                .toggleStyle(.checkbox)
                            
                            Spacer()
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    } else if selectedTab == "Device" {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Hardware Details")
                                .font(.headline)
                            
                            List {
                                HStack {
                                    Text("Selected Mouse:")
                                    Spacer()
                                    Text(selectedDevice)
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("Detection Subsystem:")
                                    Spacer()
                                    Text("IOKit Human Interface Device (HID)")
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("Active Mouse Devices:")
                                    Spacer()
                                    Text("\(tapManager.connectedMice.count - 1) connected")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .listStyle(.inset)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    } else if selectedTab == "HID Inspector" {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Raw HID Traffic (Capped at 100)")
                                    .font(.headline)
                                Spacer()
                                Button("Clear Log") {
                                    tapManager.rawHIDEvents.removeAll()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    if tapManager.rawHIDEvents.isEmpty {
                                        VStack(spacing: 8) {
                                            Image(systemName: "cpu")
                                                .font(.system(size: 24))
                                                .foregroundColor(.secondary.opacity(0.5))
                                            Text("No HID events captured yet. Move or click your mouse...")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                                .italic()
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                    } else {
                                        ForEach(tapManager.rawHIDEvents) { event in
                                            HStack(spacing: 8) {
                                                // Short format timestamp
                                                let formatter: DateFormatter = {
                                                    let f = DateFormatter()
                                                    f.dateFormat = "HH:mm:ss.SSS"
                                                    return f
                                                }()
                                                
                                                Text(formatter.string(from: event.timestamp))
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                                
                                                Text(event.deviceName)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.blue)
                                                
                                                Spacer()
                                                
                                                Text("VID: \(String(format: "0x%04X", event.vendorID)) PID: \(String(format: "0x%04X", event.productID))")
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                                
                                                Text("Page: \(String(format: "0x%02X", event.usagePage)) Usage: \(String(format: "0x%02X", event.usage))")
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundColor(.orange)
                                                
                                                Text("Val: \(event.value)")
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(event.value == 0 ? .secondary : .green)
                                            }
                                            .padding(6)
                                            .background(Color(NSColor.textBackgroundColor))
                                            .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    } else { // License & Support
                        VStack(spacing: 16) {
                            Image("mouse_icon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64, height: 64)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                            
                            Text("MouseControl Pro v1.0")
                                .font(.system(size: 14, weight: .bold))
                            
                            Text("Licensed to: Sahil Ambekar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Copyright © 2026. All rights reserved.")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            
                            Divider()
                                .frame(width: 200)
                            
                            Button("Check for Updates...") {
                                // check update action
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
                .frame(width: 320)
                .background(Color(NSColor.textBackgroundColor).opacity(0.4))
                
                Divider()
                
                // RIGHT COLUMN: Gaming Mouse Graphic & Modifiers
                VStack(spacing: 12) {
                    Spacer()
                    
                    // Mouse Illustration View
                    ZStack {
                        if let img = loadMouseIcon() {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 210, height: 210)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                        } else {
                            Image(systemName: "mouse")
                                .font(.system(size: 72))
                                .foregroundColor(.blue.opacity(0.8))
                                .frame(width: 210, height: 210)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(16)
                        }
                        
                        // Overlay hardware pulse when a button is clicked
                        if highlightedTrigger != nil {
                            Circle()
                                .stroke(Color.blue, lineWidth: 3)
                                .scaleEffect(1.2)
                                .frame(width: 210, height: 210)
                                .opacity(0.3)
                        }
                    }
                    
                    // Information Hint below illustration
                    Text("Hover your mouse cursor anywhere over this illustration. Then press any button on your actual mouse to see which button it is associated with.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Dot Page Indicators
                    HStack(spacing: 6) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Circle().fill(Color.gray.opacity(0.4)).frame(width: 6, height: 6)
                        Circle().fill(Color.gray.opacity(0.4)).frame(width: 6, height: 6)
                        Circle().fill(Color.gray.opacity(0.4)).frame(width: 6, height: 6)
                    }
                    .padding(.top, 4)
                    
                    Spacer()
                    
                    if tapManager.lastActiveKeyEvent != "None" {
                        Text("Last Key Event: \(tapManager.lastActiveKeyEvent)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 2)
                    }
                    
                    // Modifier Indicator boxes
                    HStack(spacing: 8) {
                        ModifierKeyBox(label: "⌘", isActive: pressedModifiers.contains(.command))
                        ModifierKeyBox(label: "⇧", isActive: pressedModifiers.contains(.shift))
                        ModifierKeyBox(label: "⌥", isActive: pressedModifiers.contains(.option))
                        ModifierKeyBox(label: "⌃", isActive: pressedModifiers.contains(.control))
                    }
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
        .sheet(isPresented: $showingAddSheet) {
            AddMappingSheet(
                isPresented: $showingAddSheet,
                recordingTrigger: $recordingTrigger,
                isRecording: $isRecording,
                selectedKeyCode: $selectedKeyCode,
                modifierCommand: $modifierCommand,
                modifierControl: $modifierControl,
                modifierOption: $modifierOption,
                modifierShift: $modifierShift,
                selectedDevice: selectedDevice,
                onSave: saveNewMapping
            )
        }
        .sheet(isPresented: $showingCaptureSheet) {
            MouseCaptureSheet(isPresented: $showingCaptureSheet, selectedDevice: selectedDevice)
        }
        .onAppear {
            self.startAtLogin = checkStartAtLoginStatus()
            self.isTrusted = AXIsProcessTrusted()
            
            // Add native modifier monitoring
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                self.pressedModifiers = event.modifierFlags
                return event
            }
        }
        .onReceive(timer) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted != self.isTrusted {
                self.isTrusted = trusted
                if trusted {
                    print("[SettingsView] Accessibility permissions authorized. Starting tap.")
                    tapManager.start()
                } else {
                    print("[SettingsView] Accessibility permissions revoked. Stopping tap.")
                    tapManager.stop()
                }
            }
        }
    }
    
    // Core Actions
    private func resetForm() {
        recordingTrigger = nil
        isRecording = false
        selectedKeyCode = 124 // Right arrow default
        modifierCommand = false
        modifierControl = false
        modifierOption = false
        modifierShift = false
    }
    
    private func saveNewMapping() {
        guard let trigger = recordingTrigger else { return }
        
        let mods = ModifierFlags(
            command: modifierCommand,
            control: modifierControl,
            option: modifierOption,
            shift: modifierShift
        )
        
        let shortcut = KeyboardShortcut(keyCode: selectedKeyCode, modifiers: mods)
        let newMapping = MouseMapping(trigger: trigger, shortcut: shortcut, deviceName: selectedDevice, profileName: settings.activeProfile)
        
        // Append or replace mapping if trigger and device name match in the current profile
        if let idx = settings.mappings.firstIndex(where: { $0.trigger == trigger && $0.deviceName == selectedDevice && $0.profileName == settings.activeProfile }) {
            settings.mappings[idx] = newMapping
        } else {
            settings.mappings.append(newMapping)
        }
    }
    
    private func checkStartAtLoginStatus() -> Bool {
        let service = SMAppService.mainApp
        return service.status == .enabled
    }
    
    private func setStartAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("[SettingsView] Error updating startup registration status: \(error)")
        }
    }
    
    private func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

// Helper view for modifier key indicator boxes
struct ModifierKeyBox: View {
    var label: String
    var isActive: Bool
    
    var body: some View {
        Text(label)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(isActive ? .white : .secondary)
            .frame(width: 30, height: 26)
            .background(isActive ? Color.blue : Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(isActive ? 0.0 : 0.3), lineWidth: 1)
            )
    }
}

// Inner sheet component for recording and configuring a new mapping
struct AddMappingSheet: View {
    @Binding var isPresented: Bool
    @Binding var recordingTrigger: MouseTrigger?
    @Binding var isRecording: Bool
    
    @Binding var selectedKeyCode: CGKeyCode
    @Binding var modifierCommand: Bool
    @Binding var modifierControl: Bool
    @Binding var modifierOption: Bool
    @Binding var modifierShift: Bool
    
    var selectedDevice: String
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Mouse Mapping")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 16)
            
            VStack(spacing: 16) {
                // Section 0: Target Device Name indicator
                HStack {
                    Text("Target Device:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(selectedDevice)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Section 1: Capture Mouse Event
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Record Trigger")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        if let trigger = recordingTrigger {
                            HStack(spacing: 6) {
                                Image(systemName: trigger.displayName.contains("Scroll") ? "arrow.up.and.down" : "mouse")
                                Text(trigger.displayName)
                            }
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(6)
                        } else {
                            Text("Press key recording below to record trigger")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Button(action: toggleRecording) {
                            Text(isRecording ? "Listening... (Click/Scroll)" : "Record Click / Scroll")
                                .font(.subheadline)
                                .fontWeight(isRecording ? .bold : .regular)
                                .foregroundColor(isRecording ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isRecording ? Color.red : Color.gray.opacity(0.2))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Section 2: Choose Keyboard Shortcut
                VStack(alignment: .leading, spacing: 10) {
                    Text("2. Target Keyboard Shortcut")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Modifiers Toggles
                    HStack(spacing: 14) {
                        Toggle("⌘ Cmd", isOn: $modifierCommand)
                        Toggle("⌃ Ctrl", isOn: $modifierControl)
                        Toggle("⌥ Opt", isOn: $modifierOption)
                        Toggle("⇧ Shift", isOn: $modifierShift)
                    }
                    .toggleStyle(.checkbox)
                    .font(.subheadline)
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    // Key Selection dropdown
                    HStack {
                        Text("Action Key:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedKeyCode) {
                            ForEach(availableKeys) { key in
                                Text(key.name).tag(key.keyCode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 180)
                        
                        Spacer()
                    }
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    stopRecording()
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
                
                Button("Save") {
                    onSave()
                    stopRecording()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(recordingTrigger == nil)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 440, height: 420)
        .onDisappear {
            stopRecording()
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        EventTapManager.shared.isRecording = true
        EventTapManager.shared.onMouseTriggerDetected = { trigger in
            self.recordingTrigger = trigger
            self.stopRecording()
        }
    }
    
    private func stopRecording() {
        isRecording = false
        EventTapManager.shared.isRecording = false
        EventTapManager.shared.onMouseTriggerDetected = nil
    }
}

// Dialog sheet component to capture mouse clicks/scrolls and map them
struct MouseCaptureSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var tapManager = EventTapManager.shared
    
    @State private var capturedTriggers: [MouseTrigger] = []
    @State private var selectedTriggerForMapping: MouseTrigger? = nil
    
    // Form state for creating a mapping from the captured event
    @State private var selectedKeyCode: CGKeyCode = 124 // Right arrow default
    @State private var modifierCommand = false
    @State private var modifierControl = false
    @State private var modifierOption = false
    @State private var modifierShift = false
    
    @State private var isHoveringClear = false
    @State private var isHoveringClose = false
    @State private var hoveredTriggerForMapping: MouseTrigger? = nil
    
    var selectedDevice: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Mouse Click Capture Tool")
                .font(.headline)
                .padding(.top, 16)
            
            Text("Click any mouse buttons or scroll to log events. Clicks are intercepted globally, but mouse capture is paused while hovering over the Clear, Close, or Plus buttons so they remain clickable.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            VStack {
                HStack {
                    Text("Captured Events:")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                    Button("Clear") {
                        capturedTriggers.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .onHover { hovering in
                        isHoveringClear = hovering
                        tapManager.isHoveringControl = hovering
                    }
                    .background(isHoveringClear ? Color.red.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isHoveringClear ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
                    .scaleEffect(isHoveringClear ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isHoveringClear)
                    .help("When the mouse cursor is on the clear, close, or plus button, it will not capture any event.")
                }
                .padding(.horizontal, 20)
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if capturedTriggers.isEmpty {
                            Text("Waiting for mouse inputs...")
                                .foregroundColor(.secondary)
                                .italic()
                                .font(.caption)
                                .padding(.top, 40)
                        } else {
                            ForEach(capturedTriggers, id: \.self) { trigger in
                                HStack {
                                    Image(systemName: trigger.displayName.contains("Scroll") ? "arrow.up.and.down" : "mouse")
                                        .foregroundColor(.blue)
                                    
                                    Text(trigger.displayName)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        selectedKeyCode = 124
                                        modifierCommand = false
                                        modifierControl = false
                                        modifierOption = false
                                        modifierShift = false
                                        selectedTriggerForMapping = trigger
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title2)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { hovering in
                                        tapManager.isHoveringControl = hovering
                                        if hovering {
                                            hoveredTriggerForMapping = trigger
                                        } else if hoveredTriggerForMapping == trigger {
                                            hoveredTriggerForMapping = nil
                                        }
                                    }
                                    .scaleEffect(hoveredTriggerForMapping == trigger ? 1.15 : 1.0)
                                    .animation(.easeInOut(duration: 0.15), value: hoveredTriggerForMapping)
                                    .help("When the mouse cursor is on the clear, close, or plus button, it will not capture any event.")
                                    .popover(isPresented: Binding(
                                        get: { selectedTriggerForMapping == trigger },
                                        set: { val in
                                            if val {
                                                selectedTriggerForMapping = trigger
                                            } else if selectedTriggerForMapping == trigger {
                                                selectedTriggerForMapping = nil
                                            }
                                        }
                                    )) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Map: \(trigger.displayName)")
                                                .font(.headline)
                                            
                                            Text("Choose target keyboard shortcut:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            HStack(spacing: 8) {
                                                Toggle("⌘ Cmd", isOn: $modifierCommand)
                                                Toggle("⌃ Ctrl", isOn: $modifierControl)
                                                Toggle("⌥ Opt", isOn: $modifierOption)
                                                Toggle("⇧ Shift", isOn: $modifierShift)
                                            }
                                            .toggleStyle(.checkbox)
                                            .font(.subheadline)
                                            
                                            HStack {
                                                Text("Action Key:")
                                                    .font(.subheadline)
                                                Picker("", selection: $selectedKeyCode) {
                                                    ForEach(availableKeys) { key in
                                                        Text(key.name).tag(key.keyCode)
                                                    }
                                                }
                                                .labelsHidden()
                                            }
                                            
                                            Button("Add Mapping") {
                                                let mods = ModifierFlags(
                                                    command: modifierCommand,
                                                    control: modifierControl,
                                                    option: modifierOption,
                                                    shift: modifierShift
                                                )
                                                let shortcut = KeyboardShortcut(keyCode: selectedKeyCode, modifiers: mods)
                                                let newMapping = MouseMapping(
                                                    trigger: trigger,
                                                    shortcut: shortcut,
                                                    deviceName: selectedDevice,
                                                    profileName: settings.activeProfile
                                                )
                                                
                                                if let existingIdx = settings.mappings.firstIndex(where: {
                                                    $0.trigger == trigger &&
                                                    $0.deviceName == selectedDevice &&
                                                    $0.profileName == settings.activeProfile
                                                }) {
                                                    settings.mappings[existingIdx] = newMapping
                                                } else {
                                                    settings.mappings.append(newMapping)
                                                }
                                                
                                                selectedTriggerForMapping = nil
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                        .padding(16)
                                        .frame(width: 320)
                                    }
                                }
                                .padding(10)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            }
            
            Button("Close") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(width: 100)
            .onHover { hovering in
                isHoveringClose = hovering
                tapManager.isHoveringControl = hovering
            }
            .background(isHoveringClose ? Color.blue.opacity(0.15) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHoveringClose ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isHoveringClose ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHoveringClose)
            .help("When the mouse cursor is on the clear, close, or plus button, it will not capture any event.")
            .padding(.bottom, 16)
        }
        .frame(width: 440, height: 480)
        .onAppear {
            capturedTriggers.removeAll()
            tapManager.isHoveringControl = false
            tapManager.isRecording = true
            tapManager.onMouseTriggerDetected = { trigger in
                if !capturedTriggers.contains(trigger) {
                    capturedTriggers.append(trigger)
                }
            }
        }
        .onDisappear {
            tapManager.isHoveringControl = false
            tapManager.isRecording = false
            tapManager.onMouseTriggerDetected = nil
        }
    }
}
