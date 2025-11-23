//
//  MediaViewModel.swift
//  APEX
//
//  Created by Assistant on 11/19/25.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine
import UIKit

@MainActor
final class MediaViewModel: ViewModelable {
    enum Action {
        case setSelectedIndex(Int)
        case setShowChrome(Bool)
        case setVideoPlaying(Bool)
        
        case tapShare
        case chooseShareAll
        case chooseShareSingle
        
        case tapSave
        
        case tapDelete
        case confirmDelete
        case dismissDelete
    }
    
    // Inputs (statics for the session)
    let excludedClientIds: [UUID]
    private let onSave: ((Int, MediaSource) -> Void)?
    private let onDelete: ((Int, MediaSource) -> Void)?
    
    // MARK: - UI State
    @Published var selectedIndex: Int
    @Published var pages: [MediaSource]
    
    @Published var showChrome: Bool = true
    @Published var isVideoPlaying: Bool = false
    
    @Published var showDeleteAlert: Bool = false
    
    @Published var showShareOptions: Bool = false
    @Published var showShareSheet: Bool = false
    @Published var shareAttachments: [ShareAttachmentItem] = []
    
    // MARK: - Init
    init(
        items: [MediaSource],
        selectedIndex: Int,
        excludedClientIds: [UUID] = [],
        onSave: ((Int, MediaSource) -> Void)? = nil,
        onDelete: ((Int, MediaSource) -> Void)? = nil
    ) {
        self.pages = items
        self.selectedIndex = selectedIndex
        self.excludedClientIds = excludedClientIds
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .setSelectedIndex(let idx):
            selectedIndex = idx
        case .setShowChrome(let value):
            withAnimation(.easeInOut(duration: 0.2)) { showChrome = value }
        case .setVideoPlaying(let playing):
            isVideoPlaying = playing
            
        case .tapShare:
            handleShareTapped()
        case .chooseShareAll:
            prepareShareAttachments(allInBundle: true)
        case .chooseShareSingle:
            prepareShareAttachments(allInBundle: false)
            
        case .tapSave:
            handleSave()
            
        case .tapDelete:
            showDeleteAlert = true
        case .confirmDelete:
            handleDelete()
        case .dismissDelete:
            showDeleteAlert = false
        }
    }
}

// MARK: - Private
private extension MediaViewModel {
    func handleShareTapped() {
        if pages.count > 1 {
            showShareOptions = true
        } else {
            prepareShareAttachments(allInBundle: false)
        }
    }
    
    func prepareShareAttachments(allInBundle: Bool) {
        let targets: [MediaSource]
        if allInBundle {
            targets = pages
        } else {
            guard pages.indices.contains(selectedIndex) else { return }
            targets = [pages[selectedIndex]]
        }
        
        shareAttachments = targets.compactMap { source in
            switch source {
            case .image(let data):
                if let img = UIImage(data: data) {
                    return ShareAttachmentItem(id: UUID(), kind: .image(img))
                } else {
                    return nil
                }
            case .video(let url):
                return ShareAttachmentItem(
                    id: UUID(),
                    kind: .video(url, thumbnail: generateThumbnail(for: url))
                )
            }
        }
        showShareSheet = true
        showShareOptions = false
    }
    
    func handleSave() {
        guard pages.indices.contains(selectedIndex) else { return }
        let item = pages[selectedIndex]
        if let onSave {
            onSave(selectedIndex, item)
        } else {
            defaultSave(item)
        }
    }
    
    func handleDelete() {
        guard pages.indices.contains(selectedIndex) else { return }
        let item = pages[selectedIndex]
        onDelete?(selectedIndex, item)
        
        var newPages = pages
        newPages.remove(at: selectedIndex)
        pages = newPages
        
        if selectedIndex >= pages.count {
            selectedIndex = max(0, pages.count - 1)
        }
        // View is responsible for dismissing when pages.isEmpty
    }
    
    func defaultSave(_ item: MediaSource) {
        switch item {
        case .image(let data):
            if let image = UIImage(data: data) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        case .video(let url):
            UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
        }
    }
    
    func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1600, height: 1600)
        do {
            let cgImage = try generator.copyCGImage(
                at: .init(seconds: 0.1, preferredTimescale: 600),
                actualTime: nil
            )
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}



