//
//  Note.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import Foundation
import UniformTypeIdentifiers

struct ImageAttachment {
    let data: Data
    var progress: Double? // 0.0...1.0 while uploading; nil when uploaded
    var orderIndex: Int? // Selection order to allow mixed rendering
}

struct VideoAttachment {
    let url: URL
    var progress: Double? // 0.0...1.0 while uploading; nil when uploaded
    var orderIndex: Int? // Selection order to allow mixed rendering
}

struct FileAttachment {
    let url: URL
    let contentType: UTType?
    var progress: Double? // 0.0...1.0 while uploading; nil when uploaded
}

struct AudioAttachment {
    let url: URL
    let duration: TimeInterval?
    // UI-only preferred title; when present, overrides filename in tiles
    var displayName: String? = nil
}

enum AttachmentBundle {
    case media(images: [ImageAttachment], videos: [VideoAttachment])
    case files([FileAttachment])
    case audio([AudioAttachment])
}

struct Note: Identifiable {
    var id: UUID
    var uploadedAt: Date
    var text: String?
    var bundle: AttachmentBundle?
    
    init(id: UUID = UUID(), uploadedAt: Date, text: String?, bundle: AttachmentBundle?) {
        self.id = id
        self.uploadedAt = uploadedAt
        self.text = text
        self.bundle = bundle
    }
}
