import Foundation

class AppSettings: ObservableObject {
    // Shared singleton instance
    static let shared = AppSettings()
    
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launch_at_login")
            LoginItemManager.setLaunchAtLogin(launchAtLogin)
        }
    }
    
    @Published var hasShownWelcome: Bool {
        didSet {
            UserDefaults.standard.set(hasShownWelcome, forKey: "has_shown_welcome")
        }
    }
    
    @Published var analyticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(analyticsEnabled, forKey: "analytics_enabled")
            AnalyticsService.shared.setEnabled(analyticsEnabled)
        }
    }
    
    init() {
        
        // Initialize from actual system state rather than just UserDefaults
        let storedValue = UserDefaults.standard.bool(forKey: "launch_at_login")
        let actualValue = LoginItemManager.isLaunchAtLoginEnabled()
        
        // Use actual system state if different from stored value
        launchAtLogin = actualValue
        
        // Update UserDefaults if they were out of sync
        if storedValue != actualValue {
            UserDefaults.standard.set(actualValue, forKey: "launch_at_login")
        }
        
        hasShownWelcome = UserDefaults.standard.bool(forKey: "has_shown_welcome")
        analyticsEnabled = UserDefaults.standard.object(forKey: "analytics_enabled") as? Bool ?? true // Default to enabled
    }
    
}
