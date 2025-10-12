//
//  Note.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import Foundation
import UniformTypeIdentifiers

enum Attachment {
    case text(String)
    case image(data: Data)
    case video(url: URL)
    case file(url: URL)
    case audio(url: URL)
    
    enum Kind { case text, image, video, file, audio }
    
    var kind: Kind {
        switch self {
        case .text: return .text
        case .image: return .image
        case .video: return .video
        case .file: return .file
        case .audio: return .audio
        }
    }
}

struct Note: Identifiable {
    let id = UUID()
    var date: Date
    var attachment: Attachment
}
