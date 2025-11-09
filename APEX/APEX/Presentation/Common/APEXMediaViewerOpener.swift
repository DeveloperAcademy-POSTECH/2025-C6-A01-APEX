//
//  APEXMediaViewerOpener.swift
//  APEX
//
//  Created by AI Assistant on 11/09/25.
//

import SwiftUI

struct APEXMediaViewerWrapper<Content: View>: View {
    let content: Content
    let items: [MediaSource]
    let selectedIndex: Int
    let title: String
    let uploadedAt: Date?
    let excludedClientIds: [UUID]
    var onSave: ((Int, MediaSource) -> Void)?
    var onDelete: ((Int, MediaSource) -> Void)?
    var onTitleTap: ((Int) -> Void)?

    @State private var isPresented: Bool = false

    init(
        content: Content,
        items: [MediaSource],
        selectedIndex: Int,
        title: String,
        uploadedAt: Date?,
        excludedClientIds: [UUID] = [],
        onSave: ((Int, MediaSource) -> Void)? = nil,
        onDelete: ((Int, MediaSource) -> Void)? = nil,
        onTitleTap: ((Int) -> Void)? = nil
    ) {
        self.content = content
        self.items = items
        self.selectedIndex = selectedIndex
        self.title = title
        self.uploadedAt = uploadedAt
        self.excludedClientIds = excludedClientIds
        self.onSave = onSave
        self.onDelete = onDelete
        self.onTitleTap = onTitleTap
    }

    var body: some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                isPresented = true
            }
            .fullScreenCover(isPresented: $isPresented) {
                MediaView(
                    items: items,
                    selectedIndex: min(max(0, selectedIndex), max(0, items.count - 1)),
                    title: title,
                    uploadedAt: uploadedAt,
                    excludedClientIds: excludedClientIds,
                    onSave: onSave,
                    onDelete: onDelete,
                    onTitleTap: onTitleTap
                )
            }
    }
}

extension View {
    func apexOpensMediaViewer(
        items: [MediaSource],
        index: Int,
        title: String,
        uploadedAt: Date? = nil,
        excludedClientIds: [UUID] = [],
        onSave: ((Int, MediaSource) -> Void)? = nil,
        onDelete: ((Int, MediaSource) -> Void)? = nil,
        onTitleTap: ((Int) -> Void)? = nil
    ) -> some View {
        APEXMediaViewerWrapper(
            content: self,
            items: items,
            selectedIndex: index,
            title: title,
            uploadedAt: uploadedAt,
            excludedClientIds: excludedClientIds,
            onSave: onSave,
            onDelete: onDelete,
            onTitleTap: onTitleTap
        )
    }
}


