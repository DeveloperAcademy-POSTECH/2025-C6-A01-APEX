//
//  APEXMediaViewerHost.swift
//  APEX
//
//  Created by AI Assistant on 11/09/25.
//

import SwiftUI

struct APEXOpenMediaViewerPayload: Identifiable {
    let id = UUID()
    let items: [MediaSource]
    let index: Int
    let title: String
    let uploadedAt: Date?
    let excludedClientIds: [UUID]
    var onSave: ((Int, MediaSource) -> Void)?
    var onDelete: ((Int, MediaSource) -> Void)?
    var onTitleTap: ((Int) -> Void)?

    init(
        items: [MediaSource],
        index: Int,
        title: String,
        uploadedAt: Date?,
        excludedClientIds: [UUID] = [],
        onSave: ((Int, MediaSource) -> Void)? = nil,
        onDelete: ((Int, MediaSource) -> Void)? = nil,
        onTitleTap: ((Int) -> Void)? = nil
    ) {
        self.items = items
        self.index = index
        self.title = title
        self.uploadedAt = uploadedAt
        self.excludedClientIds = excludedClientIds
        self.onSave = onSave
        self.onDelete = onDelete
        self.onTitleTap = onTitleTap
    }
}

private struct ApexOpenMediaViewerKey: EnvironmentKey {
    static let defaultValue: (APEXOpenMediaViewerPayload) -> Void = { _ in }
}

extension EnvironmentValues {
    var apexOpenMediaViewer: (APEXOpenMediaViewerPayload) -> Void {
        get { self[ApexOpenMediaViewerKey.self] }
        set { self[ApexOpenMediaViewerKey.self] = newValue }
    }
}

struct APEXMediaViewerHost<Content: View>: View {
    let content: () -> Content
    @State private var presented: APEXOpenMediaViewerPayload?

    init(@ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .environment(\.apexOpenMediaViewer, { payload in
                presented = payload
            })
            .fullScreenCover(item: $presented) { payload in
                MediaView(
                    items: payload.items,
                    selectedIndex: payload.index,
                    title: payload.title,
                    uploadedAt: payload.uploadedAt,
                    excludedClientIds: payload.excludedClientIds,
                    onSave: payload.onSave,
                    onDelete: payload.onDelete,
                    onTitleTap: payload.onTitleTap
                )
            }
    }
}


