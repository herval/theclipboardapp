import Foundation
#if canImport(PostHog)
import PostHog
#endif

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private var isEnabled = true
    private var isInitialized = false
    
    private init() {}
    
    func initialize() {
        #if canImport(PostHog)
        // Get PostHog API key from environment variable or use default
        guard let apiKey = ProcessInfo.processInfo.environment["POSTHOG_API_KEY"] else {
            print("⚠️ POSTHOG_API_KEY environment variable not set - analytics disabled")
            return
        }
        
        let config = PostHogConfig(apiKey: apiKey)
        config.debug = false
        config.flushAt = 20
        config.flushIntervalSeconds = 30
        
        PostHogSDK.shared.setup(config)
        isInitialized = true
        
        print("📊 PostHog analytics initialized")
        #else
        print("⚠️ PostHog not available - analytics disabled")
        #endif
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        
        #if canImport(PostHog)
        if isInitialized {
            if enabled {
                PostHogSDK.shared.optIn()
            } else {
                PostHogSDK.shared.optOut()
            }
        }
        #endif
        
        print("📊 Analytics \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Event Tracking
    
    func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        guard isEnabled && isInitialized else { return }
        
        #if canImport(PostHog)
        var eventProperties = properties
        eventProperties["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        eventProperties["build_number"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        
        PostHogSDK.shared.capture(event.rawValue, properties: eventProperties)
        #endif
    }
    
    func identify(userId: String, properties: [String: Any] = [:]) {
        guard isEnabled && isInitialized else { return }
        
        #if canImport(PostHog)
        PostHogSDK.shared.identify(userId, userProperties: properties)
        #endif
    }
    
    func screen(_ screenName: String, properties: [String: Any] = [:]) {
        guard isEnabled && isInitialized else { return }
        
        #if canImport(PostHog)
        var screenProperties = properties
        screenProperties["screen_name"] = screenName
        PostHogSDK.shared.screen(screenName, properties: screenProperties)
        #endif
    }
}

// MARK: - Analytics Events

enum AnalyticsEvent: String, CaseIterable {
    // App Lifecycle
    case appLaunched = "app_launched"
    case appClosed = "app_closed"
    case welcomeCompleted = "welcome_completed"
    
    // Clipboard Operations
    case clipboardItemCopied = "clipboard_item_copied"
    case clipboardHistoryOpened = "clipboard_history_opened"
    case clipboardItemPasted = "clipboard_item_pasted"
    case clipboardItemDeleted = "clipboard_item_deleted"
    
    // AI Features
    case chatWithContentOpened = "chat_with_content_opened"
    case aiMessageSent = "ai_message_sent"
    case aiResponseReceived = "ai_response_received"
    case smartPasteUsed = "smart_paste_used"
    
    // Settings
    case settingsOpened = "settings_opened"
    case aiProviderChanged = "ai_provider_changed"
    case launchAtLoginToggled = "launch_at_login_toggled"
    case analyticsToggled = "analytics_toggled"
    
    // Hotkeys
    case hotkeyUsed = "hotkey_used"
    case copyAndShowChatUsed = "copy_and_show_chat_used"
    
    // Errors
    case errorOccurred = "error_occurred"
    case aiRequestFailed = "ai_request_failed"
}

// MARK: - Convenience Extensions

extension AnalyticsService {
    
    // Quick tracking methods for common events
    
    func trackAppLaunch() {
        track(.appLaunched, properties: [
            "is_first_launch": !AppSettings.shared.hasShownWelcome
        ])
    }
    
    func trackWelcomeCompleted() {
        track(.welcomeCompleted)
    }
    
    func trackClipboardOperation(type: String, contentType: String? = nil) {
        var properties: [String: Any] = ["operation_type": type]
        if let contentType = contentType {
            properties["content_type"] = contentType
        }
        track(.clipboardItemCopied, properties: properties)
    }
    
    func trackHotkeyUsage(hotkey: String) {
        track(.hotkeyUsed, properties: ["hotkey": hotkey])
    }
    
    func trackError(_ error: Error, context: String) {
        track(.errorOccurred, properties: [
            "error_description": error.localizedDescription,
            "context": context
        ])
    }
}
