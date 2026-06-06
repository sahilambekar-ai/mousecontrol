import SwiftUI
import CoreGraphics
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var tapManager = EventTapManager.shared
    
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
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 16) {
                Image(systemName: "mouse.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("MouseControl")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Toggle("Remapping Active", isOn: $settings.isEnabled)
                    .toggleStyle(.switch)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 1. Accessibility Permission Missing Warning Block (Embedded in App)
            if !isTrusted {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        
                        Text("Accessibility Permission Required")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Text("To intercept hardware mouse clicks and trigger keyboard shortcuts in the background, macOS requires system Accessibility privileges.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 12) {
                        Button(action: openAccessibilitySettings) {
                            Text("Authorize in System Settings")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Waiting for authorization (Toggle switch ON)...")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top)
                
                Divider()
                    .padding(.top)
            }
            // 2. Diagnostic Alert Banner for Permission Cache Issues (If trusted but blocked)
            else if tapManager.hasFailedToStart {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        
                        Text("macOS System Block Alert")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Text("The keyboard remapping engine is currently blocked by macOS security. This is caused by a system Accessibility permission cache error.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 12) {
                        Button(action: openAccessibilitySettings) {
                            Text("Reset Cache in System Settings")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Text("⚠️ Please toggle the MouseControl switch OFF and then ON again.")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top)
                
                Divider()
                    .padding(.top)
            }
            
            // List of Mappings
            List {
                if settings.mappings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mouse")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("No Mappings Configured")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Click 'Add Mapping' below to configure keyboard shortcut macros for your mouse clicks or scroll wheel.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 48)
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(settings.mappings) { mapping in
                            HStack(spacing: 16) {
                                // Enabled Checkbox
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
                                
                                // Details
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mapping.trigger.displayName)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(mapping.isEnabled ? .primary : .secondary)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "keyboard")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(mapping.shortcut.displayName)
                                            .font(.system(.subheadline, design: .monospaced))
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Spacer()
                                
                                // Delete Action
                                Button(action: {
                                    settings.mappings.removeAll(where: { $0.id == mapping.id })
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.8))
                                        .font(.body)
                                }
                                .buttonStyle(.plain)
                                .help("Remove mapping")
                            }
                            .padding(.vertical, 6)
                        }
                    } header: {
                        Text("Configured Mappings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.inset)
            
            Divider()
            
            // Footer Options
            HStack {
                Toggle("Launch at startup", isOn: $startAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: startAtLogin) { newValue in
                        setStartAtLogin(newValue)
                    }
                
                Spacer()
                
                Button(action: {
                    resetForm()
                    showingAddSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Mapping")
                    }
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 560, height: 460)
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
                onSave: saveNewMapping
            )
        }
        .onAppear {
            self.startAtLogin = checkStartAtLoginStatus()
            self.isTrusted = AXIsProcessTrusted()
        }
        .onReceive(timer) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted != self.isTrusted {
                self.isTrusted = trusted
                if trusted {
                    print("[SettingsView] Accessibility permissions successfully authorized. Starting EventTapManager.")
                    EventTapManager.shared.start()
                } else {
                    print("[SettingsView] Accessibility permissions revoked. Stopping EventTapManager.")
                    EventTapManager.shared.stop()
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
        let newMapping = MouseMapping(trigger: trigger, shortcut: shortcut)
        
        // Append or replace mapping if trigger matches
        if let idx = settings.mappings.firstIndex(where: { $0.trigger == trigger }) {
            settings.mappings[idx] = newMapping
        } else {
            settings.mappings.append(newMapping)
        }
    }
    
    // Autostart Operations
    private func checkStartAtLoginStatus() -> Bool {
        let service = SMAppService.mainApp
        return service.status == .enabled
    }
    
    private func setStartAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
                print("[SettingsView] App successfully registered for auto-startup.")
            } else {
                try service.unregister()
                print("[SettingsView] App successfully unregistered from auto-startup.")
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
        
        // Also trigger the standard macOS prompt just in case it wasn't registered
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
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
    
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Mouse Mapping")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 16)
            
            VStack(spacing: 16) {
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
        .frame(width: 440, height: 380)
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
