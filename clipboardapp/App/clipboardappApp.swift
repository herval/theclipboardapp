//
//  clipboardappApp.swift
//  clipboardapp
//
//  Created by herval on 7/5/25.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct clipboardappApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    var body: some Scene {
        // No default window group; windows are created programmatically via AppDelegate.
        Settings {
            SettingsView()
                .environmentObject(AppSettings.shared)
        }
    }
}

// App delegate to handle menu bar icon setup
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusBarController: StatusBarController?
    var clipboardMonitor: ClipboardMonitor?
    var modelContainer: ModelContainer?
    var settings: AppSettings?
    var mainWindow: NSWindow?
    var settingsWindow: NSWindow?
    var globalHotkeyMonitor: GlobalHotkeyMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create the model container
        let schema = Schema([ClipboardItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            // Setup the rest of the app
            setupWithModelContainer(container, settings: AppSettings.shared)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // Listen for window notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleOpenMainWindow),
                                               name: Notification.Name("OpenMainWindow"),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleOpenSettingsWindow),
                                               name: Notification.Name("OpenSettingsWindow"),
                                               object: nil)
        
        // Register global hotkey (Cmd+Option+C) to open main window
        globalHotkeyMonitor = GlobalHotkeyMonitor()
        // Register all global hotkeys via the monitor
        globalHotkeyMonitor?.registerDefaultHotkeys(
            clipboardHistoryHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.handleOpenMainWindow()
                }
            },
        )

        
        // Only automatically open the main window if user hasn't seen welcome flow yet
        if !AppSettings.shared.hasShownWelcome {
            handleOpenMainWindow()
        }
    }
    
    func waitForClipboardUpdateAndOpenHistory(timeout: TimeInterval = 1.0) {
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount
        let start = Date()
        func poll() {
            if pasteboard.changeCount != initialChangeCount {
                self.handleOpenMainWindow()
            } else if Date().timeIntervalSince(start) < timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { poll() }
            } else {
                // Timeout fallback
                self.handleOpenMainWindow()
            }
        }
        poll()
    }

    @objc func handleOpenMainWindow() {
        print("handleOpenMainWindow called")
        // Capture the app that was frontmost BEFORE we activate our window so we can paste back correctly (e.g. Finder)
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            ClipboardPasteService.shared.lastFrontmostAppBundleID = frontApp.bundleIdentifier
            ClipboardPasteService.shared.captureFocusedElementOfFrontmostApp()
            print("Captured previous frontmost app: \(frontApp.bundleIdentifier ?? "unknown")")
        }
        // Bring our app to the foreground. This is essential for accessory apps.
        NSApp.activate(ignoringOtherApps: true)
        
        // Now, manage the window.
        if let window = mainWindow {
            // If window exists, ensure it is visible and at the front.
            print("Main window exists. Bringing it to front.")
            window.makeKeyAndOrderFront(nil)
        } else {
            // If no window exists, create one.
            print("No existing window found, creating new window.")
            createMainWindow()
        }
    }
    
    func createMainWindow() {
        // Create a new window programmatically if one doesn't exist
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                            styleMask: [.titled, .closable, .miniaturizable, .resizable],
                            backing: .buffered,
                            defer: false)
        window.title = "The Clipboard App"
        window.delegate = self
        window.center()
        window.isReleasedWhenClosed = false // Keep window instance alive
        
        // Create a hosting view for SwiftUI content
        if let modelContainer = self.modelContainer {
            // Show welcome flow if user hasn't seen it yet, otherwise show clipboard history
            if !AppSettings.shared.hasShownWelcome {
                let contentView = WelcomeView()
                    .environmentObject(AppSettings.shared)
                
                window.contentView = NSHostingView(rootView: contentView)
                window.makeKeyAndOrderFront(nil)
                mainWindow = window
            } else {
                let contentView = ClipboardHistoryView()
                    .environmentObject(AppSettings.shared)
                    .modelContainer(modelContainer)
                
                window.contentView = NSHostingView(rootView: contentView)
                window.makeKeyAndOrderFront(nil)
                mainWindow = window
            }
        } else {
            print("Error: Model container not available for main window")
        }
    }
    
    @objc func handleOpenSettingsWindow() {
        print("handleOpenSettingsWindow called")
        
        // If settings window already exists, just show it
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create a new settings window
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 450),
                           styleMask: [.titled, .closable, .miniaturizable],
                           backing: .buffered,
                           defer: false)
        window.title = "Settings"
        window.delegate = self
        window.center()
        window.isReleasedWhenClosed = false
        
        // Create a hosting view for SwiftUI content
        let contentView = SettingsView()
            .environmentObject(AppSettings.shared)
        
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setupWithModelContainer(_ container: ModelContainer, settings: AppSettings) {
        self.modelContainer = container
        self.settings = settings
        
        // Create the status bar controller now that the app is fully initialized
        if statusBarController == nil {
            statusBarController = StatusBarController()
        }
        
        // Start clipboard monitoring
        setupClipboardMonitoring()
    }
    
    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        if let win = notification.object as? NSWindow {
            if win == mainWindow {
                mainWindow = nil
            } else if win == settingsWindow {
                settingsWindow = nil
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop clipboard monitoring when app terminates
        clipboardMonitor?.stopMonitoring()
    }
    
    private func setupClipboardMonitoring() {
        // Ensure we have a model container
        guard let container = modelContainer else {
            print("Error: Model container not available")
            return
        }
        
        let context = ModelContext(container)
        print("Initializing ClipboardMonitor")
        
        // Create and start the clipboard monitor
        clipboardMonitor = ClipboardMonitor()
        clipboardMonitor?.startMonitoring(modelContext: context)
    }
}
