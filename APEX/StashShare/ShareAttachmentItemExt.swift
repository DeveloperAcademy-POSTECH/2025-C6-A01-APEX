//
//  ShareAttachmentItemExt.swift
//  StashShare
//
//  Lightweight attachment model for use inside the Share Extension.
//

import SwiftUI

struct ShareAttachmentItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case image(UIImage)
        case video(URL?, thumbnail: UIImage?)
        case file(URL)
        case text(String)
        case audio(URL)
    }
    let id: UUID
    var kind: Kind
}


