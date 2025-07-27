import Foundation
import SwiftUI
import SwiftData

class ClipboardViewState: ObservableObject {
    static let shared = ClipboardViewState()
    
    @Published var isClipboardHistoryViewOpen: Bool = false
    @Published var selectedItemID: PersistentIdentifier?
    
    private init() {}
    
    func setViewOpen(_ isOpen: Bool) {
        isClipboardHistoryViewOpen = isOpen
    }
    
    func updateSelectedItem(_ itemID: PersistentIdentifier?) {
        selectedItemID = itemID
    }
}