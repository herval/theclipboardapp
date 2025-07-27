import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    
    private let pages = [
        WelcomePage(
            icon: "clipboard",
            title: "Welcome to The Clipboard App",
            subtitle: "Your clipboard history, organized",
            description: "A simple, powerful clipboard manager that keeps track of everything you copy. Never lose important text, images, or files again."
        ),
        WelcomePage(
            icon: "clock.arrow.circlepath",
            title: "Complete Clipboard History",
            subtitle: "⌘⇧C - Never lose anything again",
            description: "Smart clipboard history keeps tabs of everything you've copied. Need something from yesterday? Simply press Cmd+Shift+C to open your history, find it, and press Enter."
        ),
        WelcomePage(
            icon: "magnifyingglass",
            title: "Quick Search",
            subtitle: "Find anything instantly",
            description: "Type any letter to start searching through your clipboard history. Find text, source apps, or any content you've copied with lightning-fast search."
        ),
        WelcomePage(
            icon: "hand.tap",
            title: "Simple & Private",
            subtitle: "Your data stays on your Mac",
            description: "All clipboard data is stored locally on your Mac. No cloud sync, no external servers. Just a clean, fast clipboard manager that respects your privacy."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            
            // Card content
        WelcomePageView(page: pages[currentPage])
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                .id(currentPage) // Force view refresh on page change
            
            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                } else {
                    Spacer()
                        .frame(width: 44) // Space for back button
                }
                
                Spacer()
                
                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Start using The Clipboard App") {
                        settings.hasShownWelcome = true
                        
                        // Close the welcome window and let the app run in menu bar
                        if let window = NSApplication.shared.keyWindow {
                            window.close()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
            .padding(.top, 20)
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct WelcomePage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
}

struct WelcomePageView: View {
    let page: WelcomePage
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .symbolVariant(.fill)
            
            // Content
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppSettings())
}
