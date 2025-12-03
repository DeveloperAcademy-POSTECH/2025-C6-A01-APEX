//
//  MediaGalleryPayload.swift
//  APEX
//
//  Structured payload for media viewer data.
//

import Foundation

struct MediaGalleryPayload {
    let items: [MediaSource]
    let anchors: [ChatMessageView.ChatAnchor]
    let index: Int
}

