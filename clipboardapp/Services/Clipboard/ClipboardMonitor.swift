//
//  ClipboardMonitor.swift
//  clipboardapp
//
//  Created by herval on 7/5/25.
//

import Foundation
import SwiftUI
import SwiftData
import AppKit
import CryptoKit
import UniformTypeIdentifiers

class ClipboardMonitor: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private var modelContext: ModelContext?
    private let viewState = ClipboardViewState.shared
    
    init() {
        lastChangeCount = pasteboard.changeCount
    }
    
    func startMonitoring(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkClipboard() {
        let currentChangeCount = pasteboard.changeCount
        
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            addClipboardItem()
        }
    }
    
    private func getCurrentApp() -> String? {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            return frontmostApp.localizedName
        }
        return nil
    }
    
    private func createThumbnail(from image: NSImage) -> Data? {
        let thumbnailSize = NSSize(width: 300, height: 300)
        
        // Get the original image's CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to get CGImage from NSImage")
            return nil
        }
        
        // Create a bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil,
                                     width: Int(thumbnailSize.width),
                                     height: Int(thumbnailSize.height),
                                     bitsPerComponent: 8,
                                     bytesPerRow: 0,
                                     space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            print("Failed to create CGContext")
            return nil
        }
        
        // Fill with white background
        context.setFillColor(CGColor.white)
        context.fill(CGRect(origin: .zero, size: thumbnailSize))
        
        // Calculate aspect fit rectangle
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let aspectRatio = imageSize.width / imageSize.height
        let thumbnailAspectRatio = thumbnailSize.width / thumbnailSize.height
        
        var drawRect: CGRect
        if aspectRatio > thumbnailAspectRatio {
            // Image is wider - fit to width
            let scaledHeight = thumbnailSize.width / aspectRatio
            drawRect = CGRect(x: 0, y: (thumbnailSize.height - scaledHeight) / 2, width: thumbnailSize.width, height: scaledHeight)
        } else {
            // Image is taller - fit to height
            let scaledWidth = thumbnailSize.height * aspectRatio
            drawRect = CGRect(x: (thumbnailSize.width - scaledWidth) / 2, y: 0, width: scaledWidth, height: thumbnailSize.height)
        }
        
        // Draw the image
        context.draw(cgImage, in: drawRect)
        
        // Create final image 
        guard let finalImage = context.makeImage() else {
            print("Failed to create final image")
            return nil
        }
        
        // Convert to PNG data instead of TIFF for better compatibility
        let bitmapRep = NSBitmapImageRep(cgImage: finalImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to create PNG data")
            return nil
        }
        
        print("Successfully created thumbnail: \(pngData.count) bytes")
        return pngData
    }
    
    // MARK: - Helpers
    private func sha256Hex(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // Insert item or update timestamp if duplicate exists
    private func insertOrUpdate(_ item: ClipboardItem, in context: ModelContext) {
        let text = item.text
        let path = item.filePath
        let descriptor: FetchDescriptor<ClipboardItem>
        if let hash = item.dataHash {
            descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate { clip in
                    clip.dataHash == hash
                }
            )
        } else {
            descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate { clip in
                    clip.text == text && clip.filePath == path && clip.dataHash == nil
                }
            )
        }
        var itemToUpdate: ClipboardItem
        if let existing = try? context.fetch(descriptor).first {
            existing.timestamp = Date()
            itemToUpdate = existing
        } else {
            context.insert(item)
            itemToUpdate = item
        }
        try? context.save()
        
        // Always notify viewState about the most recent clipboard item so any
        // observers (including the UI) can react accordingly.
        DispatchQueue.main.async {
            self.viewState.updateSelectedItem(itemToUpdate.id)
        }
    }
    
    private func addClipboardItem() {
        guard let modelContext = modelContext else { return }
        
        let sourceApp = getCurrentApp()
        let timestamp = Date()
        
        // Debug: Print all available pasteboard types
        print("=== CLIPBOARD CHANGE DETECTED ===")
        print("Available pasteboard types: \(pasteboard.types?.map { $0.rawValue } ?? [])")
        print("Change count: \(pasteboard.changeCount)")
        
        // Check what's actually available
        if let types = pasteboard.types {
            for type in types {
                print("Type: \(type.rawValue)")
                if let data = pasteboard.data(forType: type) {
                    print("  - Data size: \(data.count) bytes")
                }
            }
        }
        
        // Check for file URLs FIRST (before NSImage objects)
        print("Checking for file URLs...")
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            print("Found file URL: \(url)")
            var text = url.lastPathComponent
            var contentType = UTType.fileURL.identifier
            
            // Try to determine content type from file extension
            if let utType = UTType(filenameExtension: url.pathExtension) {
                contentType = utType.identifier
                print("Determined content type: \(contentType)")
            }
            
            // For images, create thumbnail from the file directly
            var thumbnailData: Data?
            if let utType = UTType(filenameExtension: url.pathExtension),
               utType.conforms(to: .image) {
                print("File is an image, creating thumbnail from file...")
                if let image = NSImage(contentsOf: url) {
                    print("Loaded image from file: \(image.size)")
                    thumbnailData = createThumbnail(from: image)
                    print("Created thumbnail from file: \(thumbnailData?.count ?? 0) bytes")
                    text = "[Image: \(url.lastPathComponent)]"
                } else {
                    print("Failed to load image from file")
                }
            }
            
            let newItem = ClipboardItem(
                timestamp: timestamp,
                text: text,
                filePath: url.path,
                sourceApp: sourceApp,
                contentType: contentType,
                thumbnailData: thumbnailData
            )
            insertOrUpdate(newItem, in: modelContext)
            return
        } else {
            print("No file URLs found")
        }
        
        // Check for TIFF data directly (for screenshots and direct image copies)
        print("Checking for TIFF data...")
        if let tiffData = pasteboard.data(forType: .tiff) {
            print("Found TIFF data: \(tiffData.count) bytes")
            // Convert to PNG for uniform storage/pasting
            if let rep = NSBitmapImageRep(data: tiffData),
               let pngData = rep.representation(using: .png, properties: [:]),
               let image = NSImage(data: pngData) {
                print("Converted TIFF to PNG: \(pngData.count) bytes, image size: \(image.size)")
                let hash = sha256Hex(of: pngData)
                let newItem = ClipboardItem(
                    timestamp: timestamp,
                    text: "Screenshot \(DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .medium))",
                    filePath: nil,
                    sourceApp: sourceApp,
                    contentType: UTType.png.identifier,
                    thumbnailData: pngData,
                    dataHash: hash
                )
                insertOrUpdate(newItem, in: modelContext)
                return
            } else {
                print("Failed to convert TIFF to PNG")
            }
        } else {
            print("No TIFF data found")
        }
        
        // Check for PNG data
        print("Checking for PNG data...")
        if let pngData = pasteboard.data(forType: .png) {
            print("Found PNG data: \(pngData.count) bytes")
            if let image = NSImage(data: pngData) {
                print("Created NSImage from PNG: \(image.size)")
                // Use the original PNG data for storage so it can be pasted as a file later
                let hash = sha256Hex(of: pngData)
                let newItem = ClipboardItem(
                    timestamp: timestamp,
                    text: "Screenshot \(DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .medium))",
                    filePath: nil,
                    sourceApp: sourceApp,
                    contentType: UTType.png.identifier,
                    thumbnailData: pngData,
                    dataHash: hash
                )
                insertOrUpdate(newItem, in: modelContext)
                return
            } else {
                print("Failed to create NSImage from PNG data")
            }
        } else {
            print("No PNG data found")
        }
        
        // Only check for NSImage objects as a fallback (this might be file icons)
        print("Checking for NSImage objects...")
        if let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) {
            print("Found \(objects.count) NSImage objects")
            if let image = objects.first as? NSImage {
                print("First image size: \(image.size)")
                let thumbnailData = createThumbnail(from: image)
                print("Created thumbnail data: \(thumbnailData?.count ?? 0) bytes")
                
                let newItem = ClipboardItem(
                    timestamp: timestamp,
                    text: "[Image from readObjects]",
                    filePath: nil,
                    sourceApp: sourceApp,
                    contentType: UTType.image.identifier,
                    thumbnailData: thumbnailData
                )
                insertOrUpdate(newItem, in: modelContext)
                return
            }
        } else {
            print("No NSImage objects found")
        }
        
        // Check for text
        print("Checking for text...")
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            print("Found text: \(text.prefix(50))...")
            let newItem = ClipboardItem(
                timestamp: timestamp,
                text: text,
                filePath: nil,
                sourceApp: sourceApp,
                contentType: UTType.plainText.identifier,
                thumbnailData: nil
            )
            insertOrUpdate(newItem, in: modelContext)
            return
        } else {
            print("No text found")
        }
        
        // Check for RTF text
        print("Checking for RTF...")
        if let rtfData = pasteboard.data(forType: .rtf),
           let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            print("Found RTF text: \(attributedString.string.prefix(50))...")
            let newItem = ClipboardItem(
                timestamp: timestamp,
                text: attributedString.string,
                filePath: nil,
                sourceApp: sourceApp,
                contentType: UTType.rtf.identifier,
                thumbnailData: nil
            )
            insertOrUpdate(newItem, in: modelContext)
            return
        } else {
            print("No RTF found")
        }
        
        // Check for HTML
        print("Checking for HTML...")
        if let htmlData = pasteboard.data(forType: .html),
           let htmlString = String(data: htmlData, encoding: .utf8) {
            print("Found HTML: \(htmlString.prefix(50))...")
            let newItem = ClipboardItem(
                timestamp: timestamp,
                text: htmlString,
                filePath: nil,
                sourceApp: sourceApp,
                contentType: UTType.html.identifier,
                thumbnailData: nil
            )
            insertOrUpdate(newItem, in: modelContext)
            return
        } else {
            print("No HTML found")
        }
        
        print("No supported content found on pasteboard")
    }

    deinit {
        stopMonitoring()
    }
}
