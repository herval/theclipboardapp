import SwiftUI
import AppKit

class StatusBarController {
    // MARK: - Properties
    private var statusItem: NSStatusItem
    private var popover: NSPopover?
    private var eventMonitor: EventMonitor?
    private var selectedTab: Int = 0
    
    init() {
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set the icon
        if let button = statusItem.button {
                        // Use custom icon from asset catalog
            if let menuIcon = NSImage(named: "MenuIcon") {
                button.image = menuIcon
                button.image?.isTemplate = false // Ensures proper rendering in light/dark mode
            } else {
                // Fallback to system symbol if asset is not found
                button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard App")
            }
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create a popover for showing the app content (for development/debug only)
        setupPopover()
        
        // Setup event monitor to detect clicks outside the popover
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, let popover = self.popover, popover.isShown {
                self.closePopover()
            }
        }
        
        print("StatusBarController initialized with custom view")
    }
    
    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient
        
        // Create a hosting controller for the SwiftUI view
        let contentView = ClipboardHistoryView()
            .environmentObject(AppSettings.shared)
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        self.popover = popover
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        print("Status bar button clicked: \(event.type.rawValue)")
        
        if event.type == .rightMouseUp {
            // Right-click shows menu
            statusItem.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: sender)
            // Reset the menu after it's shown to avoid conflicts with left click
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
                self?.createMenu() // Recreate the menu for next time
            }
        } else if event.type == .leftMouseUp {
            // Left-click opens main app window
            print("Left click - opening main app window")
            // Temporarily remove menu to ensure left click works
            statusItem.menu = nil
            openApp(sender)
            // Restore menu after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.createMenu()
            }
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let popover = popover {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    func showPopover() {
        if let button = statusItem.button, let popover = popover {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            eventMonitor?.start()
        }
    }
    
    func closePopover() {
        popover?.performClose(nil)
        eventMonitor?.stop()
    }
    
    func createMenu() {
        let menu = NSMenu()
        
        // Open app item
        let openItem = NSMenuItem(title: "Open Clipboard App", action: #selector(openApp(_:)), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        
        // Settings item
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Quit item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Set the menu
        statusItem.menu = menu
    }
    
    @objc func openApp(_ sender: Any?) {
        print("openApp called - triggering window opening")
        
        // First activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        // Set focus to the first tab (clipboard items list)
        selectedTab = 0
        
        // Dispatch on main queue to avoid timing issues
        DispatchQueue.main.async {
            // Post notification to trigger window creation/activation in AppDelegate
            NotificationCenter.default.post(name: Notification.Name("OpenMainWindow"), object: nil)
        }
    }
    
    @objc private func openSettings(_ sender: Any?) {
        print("openSettings called")
        NSApp.activate(ignoringOtherApps: true)
        // Post notification to open settings sheet
        NotificationCenter.default.post(name: Notification.Name("OpenSettingsWindow"), object: nil)
    }
    
    @objc private func quitApp(_ sender: Any?) {
        print("quitApp called")
        NSApp.terminate(nil)
    }
}

// Helper class to monitor events outside the popover
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}
