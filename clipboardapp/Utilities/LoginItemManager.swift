import Foundation
import ServiceManagement

class LoginItemManager {
    
    static func setLaunchAtLogin(_ enabled: Bool) {
        print("🔄 Setting launch at login: \(enabled)")
        
        if #available(macOS 13.0, *) {
            // Use modern SMAppService API for macOS 13+
            let service = SMAppService.mainApp
            print("📋 Current service status: \(service.status)")
            
            do {
                if enabled {
                    if service.status == .notRegistered || service.status.rawValue == 3 {
                        try service.register()
                        print("✅ Registered app for launch at login")
                    } else if service.status == .enabled {
                        print("ℹ️ App already registered for launch at login")
                    } else if service.status == .requiresApproval {
                        print("⚠️ Launch at login requires user approval in System Settings")
                    }
                } else {
                    if service.status == .enabled || service.status == .requiresApproval {
                        try service.unregister()
                        print("✅ Unregistered app from launch at login")
                    } else {
                        print("ℹ️ App not registered for launch at login")
                    }
                }
            } catch {
                print("❌ Failed to update launch at login: \(error)")
            }
        } else {
            // Fallback for older macOS versions
            setLaunchAtLoginLegacy(enabled)
        }
    }
    
    static func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            let status = service.status
            print("📋 Checking launch at login status: \(status.rawValue) (\(status))")
            
            // Status values: 0 = notRegistered, 1 = enabled, 2 = requiresApproval, 3 = notFound
            return status == .enabled || status == .requiresApproval
        } else {
            return isLaunchAtLoginEnabledLegacy()
        }
    }
    
    // MARK: - Legacy Support (macOS 12 and earlier)
    
    private static func setLaunchAtLoginLegacy(_ enabled: Bool) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "us.hervalicio.theclipboardapp"
        
        if enabled {
            if !SMLoginItemSetEnabled(bundleIdentifier as CFString, true) {
                print("❌ Failed to enable launch at login (legacy)")
            } else {
                print("✅ Enabled launch at login (legacy)")
            }
        } else {
            if !SMLoginItemSetEnabled(bundleIdentifier as CFString, false) {
                print("❌ Failed to disable launch at login (legacy)")
            } else {
                print("✅ Disabled launch at login (legacy)")
            }
        }
    }
    
    private static func isLaunchAtLoginEnabledLegacy() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
        
        let jobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: AnyObject]]
        return jobs?.contains { job in
            job["Label"] as? String == bundleIdentifier
        } ?? false
    }
}