import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(spacing: 24) {
                // General Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.accentColor)
                            .frame(width: 16)
                        Text("General")
                            .font(.headline)
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                                .help("Automatically launch The Clipboard App when you log in to your Mac")
                            Spacer()
                        }
                        .padding(.leading, 24)
                        
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
            Spacer()
        }
        .padding(20)
        .frame(width: 450, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
