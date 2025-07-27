# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Building the App
```bash
# Build the project in Xcode
xcodebuild -project clipboardapp.xcodeproj -scheme clipboardapp -configuration Debug build

# Or open in Xcode
open clipboardapp.xcodeproj
```

### Running Tests
```bash
# Run unit tests
xcodebuild -project clipboardapp.xcodeproj -scheme clipboardapp -destination 'platform=macOS' test

# Run specific test target
xcodebuild -project clipboardapp.xcodeproj -scheme clipboardappTests -destination 'platform=macOS' test
```

### Code Signing and Deployment
- Development team: X6ANAH85QC
- Bundle identifier: us.hervalicio.theclipboardapp
- Target platform: macOS 14.0+
- App name: "Clipboard AI"

## Architecture Overview

### Core Components

**ClipboardItem Model** (`Models/ClipboardItem.swift`)
- SwiftData model for storing clipboard history
- Stores text content, file paths, source app, content type, and thumbnail data
- Supports text, images (PNG/TIFF), RTF, HTML, and file references

**ClipboardMonitor** (`Services/Clipboard/ClipboardMonitor.swift`)
- Monitors system pasteboard changes every 0.5 seconds
- Handles multiple content types: text, images, files, RTF, HTML
- Generates thumbnails for images and creates appropriate ClipboardItem entries
- Implements deduplication logic for identical content

**App Structure**
- Uses SwiftUI with AppKit integration for menu bar functionality
- Runs as accessory app (no dock icon) with status bar presence
- Global hotkeys: Cmd+Shift+C (clipboard history)
- Programmatic window management for main and settings windows

### Key Features

**Clipboard History**
- Automatic monitoring and storage of clipboard changes
- Support for text, images, files, RTF, and HTML content
- Thumbnail generation for images
- Source app tracking
- Deduplication based on content and file path

**Search & Navigation**
- Real-time search through clipboard history
- Keyboard navigation with arrow keys
- Quick selection and pasting with Enter key

**Global Hotkeys**
- Cmd+Shift+C: Opens clipboard history window

## Dependencies

### System Frameworks
- SwiftUI: UI framework
- SwiftData: Data persistence
- AppKit: macOS-specific functionality
- UniformTypeIdentifiers: Content type handling

## File Organization

```
clipboardapp/
├── App/                    # App entry point and delegate
├── Models/                 # Data models (ClipboardItem, AppSettings, etc.)
├── Services/
│   └── Clipboard/         # Clipboard monitoring
├── Views/                 # SwiftUI views
│   ├── Clipboard/        # Clipboard history UI
│   ├── Settings/         # App settings
│   └── Welcome/          # Welcome flow
├── Utilities/            # Helper utilities and services
└── Assets.xcassets/      # App icons and resources
```

## Development Notes

### Entitlements
The app requires these sandbox entitlements:
- `com.apple.security.app-sandbox`: App sandboxing
- `com.apple.security.files.user-selected.read-only`: File access

### Global Hotkey Implementation
- Uses Carbon framework for low-level keyboard monitoring
- Hotkeys are registered in `AppDelegate.applicationDidFinishLaunching`
- Cmd+Shift+C opens clipboard history window

### SwiftData Integration
- Schema includes single ClipboardItem model
- Uses ModelContext for database operations
- Implements custom deduplication logic in ClipboardMonitor

### Settings Management
- Settings stored in AppSettings class using @AppStorage
- Preferences for launch at login, analytics, etc.
- No external API configuration needed