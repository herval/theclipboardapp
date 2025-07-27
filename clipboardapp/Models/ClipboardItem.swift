//
//  Item.swift
//  clipboardapp
//
//  Created by herval on 7/5/25.
//

import Foundation
import SwiftData
import AppKit

@Model
public final class ClipboardItem {
    public typealias ID = PersistentIdentifier

    var timestamp: Date
    var text: String
    var filePath: String?
    var sourceApp: String?
    var contentType: String?
    var thumbnailData: Data?
    var dataHash: String?
        
    init(timestamp: Date, text: String, filePath: String? = nil, sourceApp: String? = nil, contentType: String? = nil, thumbnailData: Data? = nil, dataHash: String? = nil) {
        self.timestamp = timestamp
        self.text = text
        self.filePath = filePath
        self.sourceApp = sourceApp
        self.contentType = contentType
        self.thumbnailData = thumbnailData
        self.dataHash = dataHash
    }
}
