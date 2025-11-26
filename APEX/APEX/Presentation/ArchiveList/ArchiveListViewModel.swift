//
//  ArchiveListViewModel.swift
//  APEX
//
//  Created by Assistant on 11/19/25.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

@MainActor
final class ArchiveListViewModel: ViewModelable {
    enum Action {
        case onAppear
        case setSelectedIndex(Int)
        case openRecord(URL)
        case dismissRecord
    }
    
    struct ArchiveRecordPayload: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    // Inputs (immutable)
    let initialSection: ArchiveSection
    let viewerTitle: String
    let excludedClientIds: [UUID]
    
    // Data to display (immutable snapshot for this sheet)
    let media: [FlattenedMediaItem]
    let files: [FlattenedFileItem]
    let links: [FlattenedLinkItem]
    let audios: [FlattenedAudioItem]
    
    // UI State
    @Published var selectedTab: ArchiveSection = .media
    @Published var recordPayload: ArchiveRecordPayload?
    
    // Internals
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        section: ArchiveSection,
        media: [FlattenedMediaItem],
        files: [FlattenedFileItem],
        links: [FlattenedLinkItem],
        audios: [FlattenedAudioItem],
        viewerTitle: String,
        excludedClientIds: [UUID]
    ) {
        self.initialSection = section
        self.media = media
        self.files = files
        self.links = links
        self.audios = audios
        self.viewerTitle = viewerTitle
        self.excludedClientIds = excludedClientIds
        self.selectedTab = section
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            selectedTab = initialSection
            bindNotificationsIfNeeded()
            
        case .setSelectedIndex(let idx):
            selectedTab = indexToTab(idx)
            
        case .openRecord(let url):
            recordPayload = .init(url: url)
            
        case .dismissRecord:
            recordPayload = nil
        }
    }
    
    // MARK: - Public helpers used by View
    func tabIndex(from tab: ArchiveSection) -> Int {
        switch tab {
        case .media: return 0
        case .files: return 1
        case .links: return 2
        case .audio: return 3
        }
    }
    
    func indexToTab(_ idx: Int) -> ArchiveSection {
        switch idx {
        case 0: return .media
        case 1: return .files
        case 2: return .links
        case 3: return .audio
        default: return .media
        }
    }
    
    func deleteFlattenedMedia(_ item: FlattenedMediaItem) {
        guard let clientId = excludedClientIds.first else { return }
        var notes = ChatStore.shared.notes(for: clientId)
        guard let parsed = parseFlattenedMediaId(item.id),
              let noteIndex = notes.firstIndex(where: { $0.id == parsed.noteId }),
              case var .media(images, videos) = notes[noteIndex].bundle else { return }
        if parsed.isImage {
            guard images.indices.contains(parsed.localIndex) else { return }
            images.remove(at: parsed.localIndex)
        } else {
            guard videos.indices.contains(parsed.localIndex) else { return }
            videos.remove(at: parsed.localIndex)
        }
        struct Combined { let isImage: Bool; let idx: Int; let order: Int }
        var merged: [Combined] = []
        for imageIndex in images.indices {
            let order = images[imageIndex].orderIndex ?? imageIndex
            merged.append(Combined(isImage: true, idx: imageIndex, order: order))
        }
        for videoIndex in videos.indices {
            let order = videos[videoIndex].orderIndex ?? (images.count + videoIndex)
            merged.append(Combined(isImage: false, idx: videoIndex, order: order))
        }
        merged.sort { $0.order < $1.order }
        for (newOrder, entry) in merged.enumerated() {
            if entry.isImage { images[entry.idx].orderIndex = newOrder } else { videos[entry.idx].orderIndex = newOrder }
        }
        if images.isEmpty && videos.isEmpty {
            if notes[noteIndex].text == nil {
                notes.remove(at: noteIndex)
            } else {
                notes[noteIndex].bundle = nil
            }
        } else {
            notes[noteIndex].bundle = .media(images: images, videos: videos)
        }
        ChatStore.shared.setNotes(notes, for: clientId)
        if SyncSettings.isAutoOn {
            if let idx = notes.firstIndex(where: { $0.id == parsed.noteId }) {
                CloudKitNotesManager.shared.rewriteAssets(noteId: parsed.noteId, bundle: notes[idx].bundle)
            } else {
                CloudKitNotesManager.shared.delete(noteId: parsed.noteId)
            }
        }
    }
    
    func ownerName(for item: FlattenedMediaItem) -> String? {
        guard let owner = ownerFor(item) else { return nil }
        if let client = ClientsStore.shared.clients.first(where: { $0.id == owner.clientId }) {
            return client.autoFormattedName
        }
        return nil
    }
    
    func anchor(in items: [FlattenedMediaItem], current: Int) -> (clientId: UUID, noteId: UUID)? {
        guard items.indices.contains(current) else { return nil }
        let item = items[current]
        if let parsed = parseFlattenedMediaId(item.id),
           let owner = ownerFor(item) {
            return (owner.clientId, parsed.noteId)
        }
        return nil
    }
}

// MARK: - Private
private extension ArchiveListViewModel {
    func bindNotificationsIfNeeded() {
        // If we can infer a single client id, reflect audio rename/delete changes into ChatStore
        guard let clientId = excludedClientIds.first else { return }
        cancellables.removeAll()
        
        NotificationCenter.default.publisher(for: .apexAudioRenamed)
            .sink { notif in
                guard let oldURL = notif.userInfo?["oldURL"] as? URL,
                      let newURL = notif.userInfo?["newURL"] as? URL else { return }
                var notes = ChatStore.shared.notes(for: clientId)
                var changed = false
                var changedNoteIds: Set<UUID> = []
                for idx in notes.indices {
                    if case var .audio(audios) = notes[idx].bundle {
                        var updated = false
                        for audioIndex in audios.indices where audios[audioIndex].url == oldURL {
                            audios[audioIndex] = AudioAttachment(url: newURL, duration: audios[audioIndex].duration)
                            updated = true
                        }
                        if updated {
                            notes[idx].bundle = .audio(audios)
                            changed = true
                            changedNoteIds.insert(notes[idx].id)
                        }
                    }
                }
                if changed {
                    ChatStore.shared.setNotes(notes, for: clientId)
                    if SyncSettings.isAutoOn {
                        for id in changedNoteIds {
                            if let index = notes.firstIndex(where: { $0.id == id }) {
                                CloudKitNotesManager.shared.rewriteAssets(noteId: id, bundle: notes[index].bundle)
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .apexAudioDeleted)
            .sink { notif in
                guard let url = notif.userInfo?["url"] as? URL else { return }
                var notes = ChatStore.shared.notes(for: clientId)
                var changed = false
                var changedNoteIds: Set<UUID> = []
                var removedNoteIds: Set<UUID> = []
                for idx in notes.indices {
                    if case var .audio(audios) = notes[idx].bundle {
                        let before = audios.count
                        audios.removeAll { $0.url == url }
                        if audios.count != before {
                            notes[idx].bundle = audios.isEmpty ? nil : .audio(audios)
                            changed = true
                            let noteId = notes[idx].id
                            if audios.isEmpty, notes[idx].text == nil {
                                removedNoteIds.insert(noteId)
                            } else {
                                changedNoteIds.insert(noteId)
                            }
                        }
                    }
                }
                if changed {
                    ChatStore.shared.setNotes(notes, for: clientId)
                    if SyncSettings.isAutoOn {
                        for id in changedNoteIds {
                            if let index = notes.firstIndex(where: { $0.id == id }) {
                                CloudKitNotesManager.shared.rewriteAssets(noteId: id, bundle: notes[index].bundle)
                            }
                        }
                        for id in removedNoteIds {
                            CloudKitNotesManager.shared.delete(noteId: id)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func parseFlattenedMediaId(_ id: String) -> (noteId: UUID, isImage: Bool, localIndex: Int)? {
        if let range = id.range(of: "-i-", options: .backwards) {
            let uuidPart = String(id[..<range.lowerBound])
            let indexPart = String(id[range.upperBound...])
            guard let noteId = UUID(uuidString: uuidPart), let localIndex = Int(indexPart) else { return nil }
            return (noteId, true, localIndex)
        } else if let range = id.range(of: "-v-", options: .backwards) {
            let uuidPart = String(id[..<range.lowerBound])
            let indexPart = String(id[range.upperBound...])
            guard let noteId = UUID(uuidString: uuidPart), let localIndex = Int(indexPart) else { return nil }
            return (noteId, false, localIndex)
        } else {
            return nil
        }
    }
    
    func ownerFor(_ item: FlattenedMediaItem) -> (clientId: UUID, noteId: UUID)? {
        guard let parsed = parseFlattenedMediaId(item.id) else { return nil }
        for client in ClientsStore.shared.clients {
            var notesForClient = ChatStore.shared.notes(for: client.id)
            if notesForClient.isEmpty { notesForClient = client.notes }
            if notesForClient.contains(where: { $0.id == parsed.noteId }) {
                return (client.id, parsed.noteId)
            }
        }
        return nil
    }
}


