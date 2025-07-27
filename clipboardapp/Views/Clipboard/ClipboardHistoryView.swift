//
//  ContentView.swift
//  clipboardapp
//
//  Created by herval on 7/5/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

public struct ClipboardHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var viewState = ClipboardViewState.shared
    
    let pasteboard = NSPasteboard.general
    @State private var selectedItemID: ClipboardItem.ID?
    @FocusState private var focusedItemID: ClipboardItem.ID?
    @FocusState private var listIsFocused: Bool

    // Search state
    @State private var searchText: String = ""
    @State private var searchActive: Bool = false
    @FocusState private var searchFieldFocused: Bool

    @State private var eventMonitor: Any?
    
    public var body: some View {
        NavigationStack {
            clipboardView
        }
        .tabItem {
                Label("Clipboard", systemImage: "doc.on.clipboard")
            }
            .tag(0)
        // Also ensure an item is focused whenever the list content changes (e.g., on first load)
        .onChange(of: items.count) { _, _ in
            DispatchQueue.main.async {
                if selectedItemID == nil, let first = items.first {
                    selectedItemID = first.id
                }
                listIsFocused = false
                focusedItemID = nil
                DispatchQueue.main.async {
                    listIsFocused = true
                    if let id = selectedItemID {
                        focusedItemID = id
                    }
                }
            }
        }
            .onAppear {
            viewState.setViewOpen(true)
            
            // Use viewState selectedItemID if available, otherwise select first item
            if let savedItemID = viewState.selectedItemID,
               items.contains(where: { $0.id == savedItemID }) {
                selectedItemID = savedItemID
                focusedItemID = savedItemID
            } else if let first = items.first {
                selectedItemID = first.id
                focusedItemID = first.id
                viewState.updateSelectedItem(first.id)
            }
            
            listIsFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                listIsFocused = true
                if let selectedID = selectedItemID {
                    focusedItemID = selectedID
                }
            }
            
            // Add global event monitor for ESC and Enter
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                if searchActive && event.keyCode == 53 { // ESC while searching
                    searchActive = false
                    searchText = ""
                    restoreFocusAfterSearch()
                    return nil
                } else if searchActive && (event.keyCode == 125 || event.keyCode == 126) {
                    // Down (125) / Up (126) arrow while search bar active
                    moveSelection(offset: event.keyCode == 125 ? 1 : -1)
                    return nil

                } else if event.keyCode == 36 || event.keyCode == 76 { // Return, Numpad Enter
                    pasteSelectedItemAndClose()
                    return nil
                } else if event.keyCode == 53 { // ESC
                    NSApp.keyWindow?.close()
                    return nil
                } else if event.modifierFlags.contains(.command) && event.keyCode == 51 { // Cmd+Delete
                    deleteSelectedItem()
                    return nil
                } else if !searchActive,
                          event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
                          let chars = event.charactersIgnoringModifiers,
                          chars.count == 1,
                          let scalar = chars.unicodeScalars.first,
                          CharacterSet.alphanumerics.contains(scalar) {
                    // Begin search UI and include first typed character
                    searchActive = true
                    DispatchQueue.main.async {
                        // Focus the search field first so the initial character isn't selected
                        searchFieldFocused = true
                        // Now insert the first typed character
                        searchText = String(chars)
                        // Move cursor to end (no selection) once the field becomes first-responder
                        DispatchQueue.main.async {
                            if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                                let length = editor.string.count
                                editor.setSelectedRange(NSRange(location: length, length: 0))
                            }
                        }
                    }
                    return nil
                } else if searchActive && (event.keyCode == 125 || event.keyCode == 126) {
                    // Down (125) / Up (126) arrow while search bar active
                    moveSelection(offset: event.keyCode == 125 ? 1 : -1)
                    return nil

                } else if event.keyCode == 36 || event.keyCode == 76 { // Return, Numpad Enter
                    pasteSelectedItemAndClose()
                    return nil
                }
            
                return event
            }
        }
        .onDisappear {
            viewState.setViewOpen(false)
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }

    private func pasteSelectedItemAndClose() {
        guard let selected = items.first(where: { $0.id == selectedItemID }) else { return }
        ClipboardPasteService.shared.pasteAndRestoreFocus(with: selected)
    }

    private var clipboardView: some View {
        HStack(spacing: 0) {
            // Sidebar list
            VStack(spacing: 0) {
                if searchActive {
                    HStack {
                        TextField("Search", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($searchFieldFocused)
                        Button(action: {
                            searchActive = false
                            searchText = ""
                            searchFieldFocused = false
                            restoreFocusAfterSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(6)
                }
                List(selection: $selectedItemID) {
                ForEach(displayedItems) { item in
                    ItemRowView(item: item)
                        .focused($focusedItemID, equals: item.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItemID = item.id
                            focusedItemID = item.id
                            listIsFocused = true
                            viewState.updateSelectedItem(item.id)
                        }
                }
                .onDelete(perform: deleteItems)
                }
            }
            .focused($listIsFocused)
            .frame(minWidth: 200, idealWidth: 400)
            .onChange(of: selectedItemID) { _, newValue in
                viewState.updateSelectedItem(newValue)
            }
            .onChange(of: searchText) { _, _ in
                guard searchActive else { return }
                if let first = displayedItems.first {
                    selectedItemID = first.id
                    focusedItemID = first.id
                } else {
                    selectedItemID = nil
                    focusedItemID = nil
                }
            }
            .onReceive(viewState.$selectedItemID.removeDuplicates()) { newID in
                guard let id = newID, id != selectedItemID else { return }
                if items.contains(where: { $0.id == id }) {
                    selectedItemID = id
                    focusedItemID = id
                }
            }
            
            Divider()
            
            // Detail pane
            Group {
                if let selected = items.first(where: { $0.id == selectedItemID }) {
                    ItemDetailView(item: selected)
                } else {
                    Text("Select an item")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // Move selection in filtered list
    private func moveSelection(offset: Int) {
        guard !displayedItems.isEmpty else { return }
        if selectedItemID == nil {
            selectedItemID = displayedItems.first!.id
            focusedItemID = selectedItemID
            return
        }
        if let idx = displayedItems.firstIndex(where: { $0.id == selectedItemID }) {
            let newIdx = min(max(0, idx + offset), displayedItems.count - 1)
            selectedItemID = displayedItems[newIdx].id
            focusedItemID = selectedItemID
        } else {
            // current selection not in filtered list -> choose closest
            if let first = displayedItems.first {
                selectedItemID = first.id
                focusedItemID = first.id
            }
        }
    }

    private func restoreFocusAfterSearch() {
        DispatchQueue.main.async {
            listIsFocused = true
            if let current = selectedItemID {
                focusedItemID = current
            } else if let first = displayedItems.first {
                selectedItemID = first.id
                focusedItemID = first.id
            }
        }
    }

    // Computed filtered list
    private var displayedItems: [ClipboardItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return items
        }
        let lower = searchText.lowercased()
        return items.filter { item in
            item.text.lowercased().contains(lower) ||
            (item.sourceApp?.lowercased().contains(lower) ?? false)
        }
    }

    private func deleteSelectedItem() {
        guard let selectedID = selectedItemID,
              let idx = items.firstIndex(where: { $0.id == selectedID }) else { return }
        withAnimation {
            let item = items[idx]
            modelContext.delete(item)
        }
        // Update selection to next item
        DispatchQueue.main.async {
            if idx < items.count - 1 {
                selectedItemID = items[idx + 1].id
            } else if idx > 0 {
                selectedItemID = items[idx - 1].id
            } else {
                selectedItemID = nil
            }
            focusedItemID = selectedItemID
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}




struct ItemRowView: View {
    let item: ClipboardItem
    
    var body: some View {
        HStack {
            // Thumbnail or icon
            if let thumbnailData = item.thumbnailData,
               let nsImage = NSImage(data: thumbnailData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onAppear {
                        print("ItemRowView: Successfully displaying thumbnail: \(thumbnailData.count) bytes, image size: \(nsImage.size)")
                    }
            } else {
                Image(systemName: contentTypeIcon(for: item.contentType))
                    .frame(width: 40, height: 40)
                    .foregroundColor(.secondary)
                    .onAppear {
                        if let thumbnailData = item.thumbnailData {
                            print("ItemRowView: Has thumbnail data (\(thumbnailData.count) bytes) but failed to create NSImage")
                        } else {
                            print("ItemRowView: No thumbnail data for item")
                        }
                    }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .lineLimit(2)
                    .font(.system(size: 14))
                
                HStack {
                    if let sourceApp = item.sourceApp {
                        Text(sourceApp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private func contentTypeIcon(for contentType: String?) -> String {
        guard let contentType = contentType else { return "doc" }
        
        if contentType.contains("image") {
            return "photo"
        } else if contentType.contains("text") {
            return "doc.text"
        } else if contentType.contains("url") {
            return "link"
        } else if contentType.contains("rtf") {
            return "doc.richtext"
        } else if contentType.contains("html") {
            return "globe"
        } else {
            return "doc"
        }
    }
}

struct ItemDetailView: View {
    let item: ClipboardItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Thumbnail/Content
                if let thumbnailData = item.thumbnailData,
                   let nsImage = NSImage(data: thumbnailData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onAppear {
                            print("ItemDetailView: Successfully displaying thumbnail: \(thumbnailData.count) bytes, image size: \(nsImage.size)")
                        }
                } else {
                    if let thumbnailData = item.thumbnailData {
                        Text("Failed to display thumbnail (\(thumbnailData.count) bytes)")
                            .foregroundColor(.red)
                            .onAppear {
                                print("ItemDetailView: Has thumbnail data (\(thumbnailData.count) bytes) but failed to create NSImage")
                            }
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.text)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                }
                
                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("Metadata")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Label(item.timestamp.formatted(date: .abbreviated, time: .standard), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let sourceApp = item.sourceApp {
                        Label("Source App: \(sourceApp)", systemImage: "app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let filePath = item.filePath {
                        Label("File Path: \(filePath)", systemImage: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Label("Content Type: \(item.contentType ?? "Unknown")", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct ContentViewPreview: View {
    @State private var selectedTab = 0
    
    var body: some View {
        let exampleItems = [
            ClipboardItem(timestamp: Date(), text: "First copied text", filePath: nil, sourceApp: "Safari", contentType: "text/plain", thumbnailData: nil),
            ClipboardItem(timestamp: Date().addingTimeInterval(-60), text: "Second copied text", filePath: nil, sourceApp: "Notes", contentType: "text/plain", thumbnailData: nil)
        ]
        let container = try! ModelContainer(for: ClipboardItem.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        exampleItems.forEach { context.insert($0) }
        return ClipboardHistoryView()
            .modelContainer(container)
            .environmentObject(AppSettings())
    }
}

#Preview {
    ContentViewPreview()
}
