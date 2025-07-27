import Foundation
import ServiceManagement

class LoginItemManager {
    
    static func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            // Use modern SMAppService API for macOS 13+
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status == .notRegistered {
                        try service.register()
                        print("✅ Registered app for launch at login")
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                        print("✅ Unregistered app from launch at login")
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
            return service.status == .enabled
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