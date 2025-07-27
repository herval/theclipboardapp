# The Clipboard App

A simple, powerful clipboard manager for macOS that keeps track of your clipboard history and makes it easy to find and reuse anything you've copied.

## Features

- 📋 **Automatic Clipboard History** - Tracks all your copied content (text, images, files, RTF, HTML)
- 🔍 **Smart Search** - Quickly find items in your clipboard history
- ⌨️ **Global Hotkeys** - Access clipboard history with `Cmd+Shift+C`
- 🖼️ **Image Support** - Automatic thumbnail generation for copied images
- 📱 **Menu Bar App** - Runs quietly in your menu bar, no dock icon
- 🔒 **Privacy First** - All data stored locally on your Mac

## Installation

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/clipboardapp.git
cd clipboardapp

# Open in Xcode
open clipboardapp.xcodeproj

# Or build from command line
./build.sh
```

## Quick Start

1. **Launch the app** - It will appear in your menu bar
2. **Copy something** - The app automatically tracks all clipboard changes
3. **Access history** - Press `Cmd+Shift+C` to open your clipboard history
4. **Paste items** - Select any item and press Enter to paste it back

## Keyboard Shortcuts

- `Cmd+Shift+C` - Open clipboard history window
- `Enter` - Paste selected item and close window
- `Escape` - Close window
- `Cmd+Delete` - Delete selected item
- Type any letter/number - Start searching

## Configuration

No additional configuration needed - the app works out of the box!

## Development

### Prerequisites

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### Dependencies

- SwiftUI - User interface
- SwiftData - Local data persistence
- AppKit - macOS system integration

### Project Structure

```
clipboardapp/
├── App/                    # App entry point and delegate
├── Models/                 # Data models (ClipboardItem, Settings, etc.)
├── Services/
│   └── Clipboard/         # Clipboard monitoring
├── Views/                 # SwiftUI views
│   ├── Clipboard/        # Clipboard history UI
│   ├── Settings/         # App settings
│   └── Welcome/          # Welcome flow
├── Utilities/            # Helper utilities and services
└── Assets.xcassets/      # App icons and resources
```

### Building

```bash
# Development build
xcodebuild -project clipboardapp.xcodeproj -scheme clipboardapp build

# Distribution build with notarization
./build.sh

# Run tests
xcodebuild -project clipboardapp.xcodeproj -scheme clipboardapp test
```

## Privacy & Security

- **Local Storage**: All clipboard data is stored locally using SwiftData
- **No Cloud Sync**: Your clipboard history never leaves your Mac
- **Optional Analytics**: Privacy-focused analytics can be disabled in settings
- **Sandboxed**: App runs in macOS sandbox for additional security
- **Code Signed**: Releases are code signed and notarized by Apple

## Permissions Required

- **Accessibility** - To monitor global keyboard shortcuts
- **File Access** - To read copied files and images (user-selected only)

## System Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

- 🐛 **Bug Reports**: [Open an issue](https://github.com/yourusername/clipboardapp/issues)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
