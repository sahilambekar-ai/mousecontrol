import Cocoa

// Initialize the shared NSApplication instance
let app = NSApplication.shared

// Instantiated core app lifecycle delegate
let delegate = AppDelegate()
app.delegate = delegate

// Enter AppKit event execution loop (never returns during active running)
app.run()
