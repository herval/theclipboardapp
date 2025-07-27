import AppKit
import Cocoa
import UniformTypeIdentifiers
import Accessibility

class ClipboardPasteService {
    static let shared = ClipboardPasteService()
    var lastFrontmostAppBundleID: String?
    private var previouslyFocusedElement: AXUIElement?
    private var pasteSent = false
    private var previouslyFocusedPID: pid_t?
    private init() {}

    // Call this before opening the clipboard window
    func captureFocusedElementOfFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            print("No frontmost application found")
            return 
        }
        
        let pid = app.processIdentifier
        self.previouslyFocusedPID = pid
        self.lastFrontmostAppBundleID = app.bundleIdentifier
        
        print("Capturing focused element for: \(app.localizedName ?? "Unknown app") (\(pid))")
        
        // Get the application's AXUIElement
        let appRef = AXUIElementCreateApplication(pid)
        
        // Get the focused UI element
        var rawValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &rawValue)
        
        if result == .success && rawValue != nil {
            self.previouslyFocusedElement = rawValue as! AXUIElement
            
            // Get element role for better debugging
            var roleValue: AnyObject?
            if AXUIElementCopyAttributeValue(self.previouslyFocusedElement!, kAXRoleAttribute as CFString, &roleValue) == .success {
                let role = roleValue as! String
                print("✅ Captured focused UI element: \(role)")
            } else {
                print("✅ Captured focused UI element (unknown role)")
            }
        } else {
            self.previouslyFocusedElement = nil
            print("❌ Failed to capture focused element: \(result.rawValue)")
            
            // Fallback - try to capture the main window
            var windowValue: AnyObject?
            if AXUIElementCopyAttributeValue(appRef, kAXMainWindowAttribute as CFString, &windowValue) == .success,
               let window = windowValue {
                self.previouslyFocusedElement = window as! AXUIElement
                print("⚠️ Fallback to main window capture")
            }
        }
    }

    // MARK: - UTI helpers
    private func isImageType(_ type: String) -> Bool {
        if let ut = UTType(type) {
            return ut.conforms(to: .image)
        }
        let lower = type.lowercased()
        return lower.hasPrefix("image") || lower.contains("public.png") || lower.contains("public.jpeg") || lower.contains("public.tiff")
    }

    func pasteAndRestoreFocus(with item: ClipboardItem, completion: (() -> Void)? = nil) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var wroteSomething = false
        var wroteFileURL = false
        // Determine if we are pasting back into Finder
        let isPastingIntoFinder = (self.lastFrontmostAppBundleID == "com.apple.finder") || (NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder")
        
        // Write file if available and valid
        if let filePath = item.filePath, FileManager.default.fileExists(atPath: filePath) {
            let fileURL = URL(fileURLWithPath: filePath)
            if pasteboard.writeObjects([fileURL as NSURL]) {
                print("Wrote file to pasteboard: \(filePath)")
                wroteSomething = true
                wroteFileURL = true
            }
        }

        // Write image if available and valid (skip when pasting into Finder and file URL already on the pasteboard)
        if !(isPastingIntoFinder && wroteFileURL),
           let contentType = item.contentType, isImageType(contentType),
           let data = item.thumbnailData, let image = NSImage(data: data) {
            if pasteboard.writeObjects([image]) {
                print("Wrote image to pasteboard")
                wroteSomething = true
            }
        }
        if let contentType = item.contentType, isImageType(contentType),
           let data = item.thumbnailData, let image = NSImage(data: data) {
            if pasteboard.writeObjects([image]) {
                print("Wrote image to pasteboard")
                wroteSomething = true
            }
        }

        // If pasting into Finder and item is not already a file, try to materialize it as a temporary file so Finder can create a new file when Cmd+V is pressed.
        var tempFileURL: URL? = nil
        if isPastingIntoFinder && item.filePath == nil {
            if let tempURL = createTemporaryFile(from: item) {
                tempFileURL = tempURL
                if pasteboard.writeObjects([tempURL as NSURL]) {
                    print("Wrote temporary file to pasteboard for Finder: \(tempURL.path)")
                    wroteSomething = true
                }
            }
        }

        // If we successfully wrote a temp file for Finder we do NOT write text, otherwise Finder prioritizes the text representation
        if tempFileURL == nil, !item.text.isEmpty {
            if pasteboard.setString(item.text, forType: .string) {
                print("Wrote text to pasteboard: \(item.text.prefix(40)))")
                wroteSomething = true
            }
        }

        if !wroteSomething {
            print("Nothing written to pasteboard for item: \(item)")
        }

        // Hide our app quickly
        NSApp.hide(nil)
        // Send Cmd+V after a tiny delay to allow focus to return to previous app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.sendCmdV()
            completion?()
        }
    }

    private func reactivatePreviousAppAndPaste(timeout: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        // If we have no record of the previous frontmost app, just wait for our app to deactivate and then paste
        guard let bundleID = self.lastFrontmostAppBundleID else {
            print("❓ lastFrontmostAppBundleID missing – fallback to waitForAppDeactivation")
            waitForAppDeactivationAndPaste(timeout: timeout, completion: completion)
            return
        }
        
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            print("❓ Previous app not found – fallback to waitForAppDeactivation")
            waitForAppDeactivationAndPaste(timeout: timeout, completion: completion)
            return
        }
        
        print("Attempting to restore focus to \(app.localizedName ?? bundleID)")
        
        // First try to activate the previous app
        app.activate(options: [])
        
        // Then poll to ensure it's frontmost before sending Cmd+V
        let timeout: TimeInterval = 1.0  // Timeout after 1 second of polling
        let start = Date()
        
        func poll() {
            guard let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { poll() }
                return
            }
            
            print("Polling for focus: frontmost is \(frontmost), want \(bundleID)")
            if frontmost == bundleID {
                print("Focus restored, attempting to restore UI element focus")
                
                // Try to restore the exact UI element that was focused previously
                // Give UI time to stabilize after activation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    // First, try to restore specific element focus
                    let elementRestored = self.restoreFocusToElement()
                    print("Element focus restoration: \(elementRestored ? "succeeded" : "failed")")
                    
                    // If element focus failed, try window focus
                    if !elementRestored {
                        self.focusMainWindowAX(of: app)
                    }
                    
                    // Wait another tiny bit for UI to stabilize after focus changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        // As a last-ditch effort, click the center of the window to force focus
                        self.clickCenterOfFrontmostWindow()
                        
                        // Now send the paste command
                        self.sendCmdV()
                        print("Paste command sent to \(app.localizedName ?? bundleID)")
                        completion?()
                    }
                }
            } else if Date().timeIntervalSince(start) < timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { poll() }
            } else {
                print("Timeout waiting for focus restoration, sending Cmd+V anyway")
                self.sendCmdV()
                completion?()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { poll() }
    }

    private func focusMainWindowAX(of app: NSRunningApplication) {
        self.sendCmdV()
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
        
        // Try to get the main window
        var mainWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &mainWindow)
        if result == .success, let window = mainWindow {
            // Try to set the main window as the focused UI element
            let mainResult = AXUIElementSetAttributeValue(window as! AXUIElement, kAXMainAttribute as CFString, kCFBooleanTrue)
            let focusResult = AXUIElementSetAttributeValue(window as! AXUIElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            print("AX window focus results - Main: \(mainResult.rawValue), Focus: \(focusResult.rawValue)")
        } else {
            print("Failed to get main window: \(result.rawValue)")
        }
    }
    
    private func clickCenterOfFrontmostWindow() {
        guard let window = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let frontmostWindowInfo = window.first,
              let boundsDict = frontmostWindowInfo[kCGWindowBounds as String] as? [String: CGFloat],
              let x = boundsDict["X"],
              let y = boundsDict["Y"],
              let w = boundsDict["Width"],
              let h = boundsDict["Height"] else {
            return
        }
        let cx = x + w / 2.0
        let cy = y + h / 2.0
        let loc = CGPoint(x: cx, y: cy)
        let src = CGEventSource(stateID: .combinedSessionState)
        let mouseDown = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: loc, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: loc, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }

    private func restoreFocusToElement() -> Bool {
        guard let element = previouslyFocusedElement, 
              let pid = previouslyFocusedPID,
              let app = NSRunningApplication(processIdentifier: pid),
              app.isActive else {
            print("⚠️ Cannot restore focus: missing element, pid, or app not active")
            return false
        }
        
        // Try to focus the specific element we captured earlier
        let result = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        
        // Get element role for better debugging
        var roleValue: AnyObject?
        var elementDesc = "unknown"
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success {
            elementDesc = roleValue as! String
        }
        
        if result == .success {
            print("✅ Successfully restored focus to \(elementDesc) element")
            return true
        } else {
            print("❌ Failed to restore focus to \(elementDesc) element: \(result.rawValue)")
            return false
        }
    }

    private func waitForAppDeactivationAndPaste(timeout: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        let start = Date()
        func poll() {
            if !NSApp.isActive {
                if !self.pasteSent {
                    self.pasteSent = true
                    if restoreFocusToElement() {
                        self.sendCmdV()
                    } else if let app = NSWorkspace.shared.frontmostApplication {
                        self.focusMainWindowAX(of: app)
                        self.sendCmdV()
                    } else {
                        // Just send Cmd+V if we can't get the frontmost app
                        self.sendCmdV()
                    }
                    completion?()
                }
            } else if Date().timeIntervalSince(start) < timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { poll() }
            } else {
                // Fallback: paste anyway after timeout
                self.sendCmdV()
                completion?()
            }
        }
        poll()
    }

    // MARK: - Helper to create temporary file for Finder pastes
    private func createTemporaryFile(from item: ClipboardItem) -> URL? {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let timestamp = Int(Date().timeIntervalSince1970)

        func writeData(_ data: Data, name: String) -> URL? {
            let url = tmpDir.appendingPathComponent(name)
            do {
                try data.write(to: url)
                return url
            } catch {
                print("Failed to write temp data file \(name): \(error)")
                return nil
            }
        }

        func writeText(_ text: String, name: String) -> URL? {
            let url = tmpDir.appendingPathComponent(name)
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                return url
            } catch {
                print("Failed to write temp text file \(name): \(error)")
                return nil
            }
        }

        // If item is an image, save PNG file
        if let typeStr = item.contentType, isImageType(typeStr), let data = item.thumbnailData {
            return writeData(data, name: "ClipboardImage_\(timestamp).png")
        }
        
        // Handle HTML and text types
        if let type = item.contentType?.lowercased() {
            if type.contains("html") {
                return writeText(item.text, name: "ClipboardHTML_\(timestamp).html")
            } else if type.contains("text") || type == UTType.plainText.identifier.lowercased() {
                return writeText(item.text, name: "ClipboardText_\(timestamp).txt")
            }
        }

        // If we have raw image data but no recognized image contentType
        if let data = item.thumbnailData, item.contentType == nil {
            return writeData(data, name: "ClipboardImage_\(timestamp).png")
        }

        // Fallback – save as plain text when we have text content
        if !item.text.isEmpty {
            return writeText(item.text, name: "ClipboardText_\(timestamp).txt")
        }

        return nil
    }

    private func sendCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true) // Cmd
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // V
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        let loc = CGEventTapLocation.cghidEventTap
        cmdDown?.post(tap: loc)
        vDown?.post(tap: loc)
        vUp?.post(tap: loc)
        cmdUp?.post(tap: loc)
    }
}
