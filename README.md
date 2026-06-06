# MouseControl 🖱️

MouseControl is a lightweight, native macOS menu-bar utility written in Swift and SwiftUI. It allows you to map extra mouse buttons (e.g., side buttons like Button 4/5) and scroll wheel directions to standard keyboard shortcuts or system actions (such as switching spaces, triggering Mission Control, or custom shortcuts).

---

## Key Features

- **Global Event Interception**: Swallows specific mouse/scroll inputs and translates them into simulated keyboard presses.
- **Menu Bar Residency (`LSUIElement`)**: Runs purely in the menu bar with no Dock icon cluttering your workspace.
- **Dynamic Configuration GUI**: Features a clean SwiftUI dashboard to customize mappings, record shortcuts, and toggle remapping on/off.
- **Robust Persistence**: Configurations are stored atomically in `~/Library/Application Support/MouseControl/config.json` as a safeguard against system force-quits, with fallback synchronization to `UserDefaults`.
- **Automatic Asset Generation**: Build script leverages native macOS tools (`sips` and `iconutil`) to scale and generate high-resolution Apple `.icns` files on the fly.

---

## Getting Started

### Prerequisites

- **macOS**: 13.0 (Ventura) or later.
- **Command Line Tools / Xcode**: Required for the `swiftc` compiler and Apple developer tools (`xcrun`, `sips`, `iconutil`).

### 1. Build the Application

We include a custom shell script that cleans old targets, compiles resources, and compiles the Swift binary.

Run the build script in your terminal:

```bash
chmod +x build.sh
./build.sh
```

This will construct a standalone macOS application bundle: **`MouseControl.app`**.

### 2. Launch the Application

You can open the compiled application bundle directly from the finder or from your terminal:

```bash
open MouseControl.app
```

Once running, you will see a mouse icon (or 🖱️ emoji fallback) in your macOS system status bar.

---

## Granting Accessibility Permissions

Because MouseControl listens for and translates system-wide mouse events using a low-level event tap (`CGEventTap`), macOS requires that you grant it **Accessibility** permissions.

If the application is launched without these permissions, it will automatically present a settings window with a warning banner:

1. Open your macOS **System Settings**.
2. Navigate to **Privacy & Security** > **Accessibility**.
3. Click the `+` button and add **`MouseControl.app`** from the directory where you built it, or toggle the switch next to it if it is already in the list.
4. Restart MouseControl if prompted, or use the menu bar icon to toggle remapping.

---

## Project Structure

- **`main.swift`**: Entry point of the application. Instantiates the AppKit event loop.
- **`AppDelegate.swift`**: Handles application lifecycle, status menu construction, settings window initialization, and permission checking.
- **`EventTapManager.swift`**: Manages the low-level `CGEventTap` to intercept, swallow, or forward mouse button presses and scroll wheel ticks.
- **`KeySimulator.swift`**: Simulates virtual keyboard shortcut presses using low-level CoreGraphics APIs (`CGEvent(keyboardEventSource:...)`).
- **`AppSettings.swift`**: Manages persistence of custom mappings.
- **`Models.swift`**: Key definitions, structures, and helper schemas.
- **`SettingsView.swift`**: The SwiftUI user interface for managing mappings.
- **`build.sh`**: Automatic build utility that compiles code and resources.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
