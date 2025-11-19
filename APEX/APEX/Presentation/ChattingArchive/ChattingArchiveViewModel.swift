//
//  ChattingArchiveViewModel.swift
//  APEX
//
//  Created by Assistant on 11/19/25.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import UniformTypeIdentifiers

@MainActor
final class ChattingArchiveViewModel: ViewModelable {
    enum Action {
        case onAppear
        case reload
        
        case toggleFavorite
        case setFavorite(Bool)
        
        case presentArchive(ArchiveSection)
        case dismissArchive
        
        case openRecord(URL)
        case dismissRecord
        
        case showDeleteMediaPrompt(Bool)
        case deleteAllMedia
        
        case showDeleteContactOverlay(Bool)
        case confirmDeleteContact
    }
    
    struct DetailRecordPayload: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    struct ArchiveSheetPayload: Identifiable {
        let id = UUID()
        let section: ArchiveSection
    }
    
    // Inputs
    let client: Client?
    private let onDeletedContact: (() -> Void)?
    
    // UI State
    @Published var isFavorite: Bool = false
    
    @Published var mediaItems: [FlattenedMediaItem] = []
    @Published var fileItems: [FlattenedFileItem] = []
    @Published var audioItems: [FlattenedAudioItem] = []
    @Published var linkItems: [FlattenedLinkItem] = []
    
    @Published var totalMediaBytes: Int64 = 0
    
    @Published var recordPayload: DetailRecordPayload?
    @Published var archiveSheet: ArchiveSheetPayload?
    
    @Published var showDeleteMediaAlert: Bool = false
    @Published var showDeleteContactOverlay: Bool = false
    @Published var isDeleteConfirmChecked: Bool = false
    
    // Internals
    private var cancellables: Set<AnyCancellable> = []
    
    init(client: Client?, onDeletedContact: (() -> Void)?) {
        self.client = client
        self.onDeletedContact = onDeletedContact
        self.isFavorite = client?.favorite ?? false
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            isFavorite = client?.favorite ?? false
            reloadMediaPreview()
            bindNotifications()
            
        case .reload:
            reloadMediaPreview()
            
        case .toggleFavorite:
            setFavorite(!isFavorite)
        case .setFavorite(let newValue):
            setFavorite(newValue)
            
        case .presentArchive(let section):
            archiveSheet = .init(section: section)
        case .dismissArchive:
            archiveSheet = nil
            
        case .openRecord(let url):
            recordPayload = .init(url: url)
        case .dismissRecord:
            recordPayload = nil
            
        case .showDeleteMediaPrompt(let show):
            showDeleteMediaAlert = show
        case .deleteAllMedia:
            deleteAllMediaDataForCurrentClient()
            
        case .showDeleteContactOverlay(let show):
            showDeleteContactOverlay = show
            if !show { isDeleteConfirmChecked = false }
        case .confirmDeleteContact:
            guard isDeleteConfirmChecked else { return }
            deleteCurrentContact()
            showDeleteContactOverlay = false
            isDeleteConfirmChecked = false
        }
    }
}

// MARK: - Private - Notifications
private extension ChattingArchiveViewModel {
    func bindNotifications() {
        cancellables.removeAll()
        
        NotificationCenter.default.publisher(for: .apexChatNotesUpdated)
            .sink { [weak self] notif in
                guard let self else { return }
                guard let changedId = notif.userInfo?["clientId"] as? UUID,
                      let currentId = self.client?.id,
                      changedId == currentId else { return }
                self.reloadMediaPreview()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .apexAudioRenamed)
            .sink { [weak self] notif in
                guard let self else { return }
                guard let oldURL = notif.userInfo?["oldURL"] as? URL,
                      let newURL = notif.userInfo?["newURL"] as? URL,
                      let clientId = self.client?.id else { return }
                var notes = ChatStore.shared.notes(for: clientId)
                var changed = false
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
                        }
                    }
                }
                if changed {
                    ChatStore.shared.setNotes(notes, for: clientId)
                    self.reloadMediaPreview()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .apexAudioDeleted)
            .sink { [weak self] notif in
                guard let self else { return }
                guard let url = notif.userInfo?["url"] as? URL,
                      let clientId = self.client?.id else { return }
                var notes = ChatStore.shared.notes(for: clientId)
                var changed = false
                for idx in notes.indices {
                    if case var .audio(audios) = notes[idx].bundle {
                        let before = audios.count
                        audios.removeAll { $0.url == url }
                        if audios.count != before {
                            notes[idx].bundle = audios.isEmpty ? nil : .audio(audios)
                            changed = true
                        }
                    }
                }
                if changed {
                    notes.removeAll { $0.text == nil && $0.bundle == nil }
                    ChatStore.shared.setNotes(notes, for: clientId)
                    self.reloadMediaPreview()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Private - Data
private extension ChattingArchiveViewModel {
    func reloadMediaPreview() {
        guard let clientId = client?.id else {
            mediaItems = []; fileItems = []; audioItems = []; linkItems = []
            totalMediaBytes = 0
            return
        }
        var notes = ChatStore.shared.notes(for: clientId)
        if notes.isEmpty {
            notes = client?.notes ?? []
        }
        mediaItems = computeMediaItems(from: notes)
        fileItems = computeFileItems(from: notes)
        audioItems = computeAudioItems(from: notes)
        linkItems = computeLinkItems(from: notes)
        totalMediaBytes = computeTotalMediaBytes(from: notes)
    }
    
    func computeMediaItems(from notes: [Note]) -> [FlattenedMediaItem] {
        var result: [FlattenedMediaItem] = []
        for note in notes {
            guard case let .media(images, videos)? = note.bundle else { continue }
            struct LocalEntry { let isImage: Bool; let index: Int; let order: Int }
            var merged: [LocalEntry] = []
            for imageIndex in images.indices {
                let order = images[imageIndex].orderIndex ?? imageIndex
                merged.append(LocalEntry(isImage: true, index: imageIndex, order: order))
            }
            for videoIndex in videos.indices {
                let order = videos[videoIndex].orderIndex ?? (images.count + videoIndex)
                merged.append(LocalEntry(isImage: false, index: videoIndex, order: order))
            }
            merged.sort { $0.order < $1.order }
            for entry in merged {
                if entry.isImage {
                    let data = images[entry.index].data
                    let id = "\(note.id.uuidString)-i-\(entry.index)"
                    result.append(.init(id: id, isVideo: false, imageData: data, videoURL: nil, uploadedAt: note.uploadedAt, localOrder: entry.order))
                } else {
                    let url = videos[entry.index].url
                    let id = "\(note.id.uuidString)-v-\(entry.index)"
                    result.append(.init(id: id, isVideo: true, imageData: nil, videoURL: url, uploadedAt: note.uploadedAt, localOrder: entry.order))
                }
            }
        }
        return result.sorted {
            if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
            if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localOrder > $1.localOrder }
            return $0.id > $1.id
        }
    }
    
    func computeFileItems(from notes: [Note]) -> [FlattenedFileItem] {
        var result: [FlattenedFileItem] = []
        for note in notes {
            if case let .files(fileSet)? = note.bundle {
                for (index, fileAttachment) in fileSet.enumerated() {
                    result.append(.init(id: "\(note.id.uuidString)-f-\(index)", url: fileAttachment.url, contentType: fileAttachment.contentType, uploadedAt: note.uploadedAt, localIndex: index))
                }
            }
        }
        return result.sorted {
            if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
            if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localIndex < $1.localIndex }
            return $0.id > $1.id
        }
    }
    
    func computeAudioItems(from notes: [Note]) -> [FlattenedAudioItem] {
        var result: [FlattenedAudioItem] = []
        for note in notes {
            if case let .audio(audioSet)? = note.bundle {
                for (index, audioAttachment) in audioSet.enumerated() {
                    result.append(.init(id: "\(note.id.uuidString)-a-\(index)", url: audioAttachment.url, duration: audioAttachment.duration, uploadedAt: note.uploadedAt, localIndex: index))
                }
            }
        }
        return result.sorted {
            if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
            if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localIndex < $1.localIndex }
            return $0.id > $1.id
        }
    }
    
    func computeLinkItems(from notes: [Note]) -> [FlattenedLinkItem] {
        var all: [FlattenedLinkItem] = []
        for note in notes {
            guard let text = note.text else { continue }
            let found = urls(in: text, limit: Int.max)
            for foundURL in found {
                all.append(.init(id: "\(note.id.uuidString)-l-\(foundURL.absoluteString)", url: foundURL, uploadedAt: note.uploadedAt))
            }
        }
        let sorted = all.sorted { $0.uploadedAt == $1.uploadedAt ? $0.id > $1.id : $0.uploadedAt > $1.uploadedAt }
        var seen = Set<String>()
        var dedup: [FlattenedLinkItem] = []
        for item in sorted where seen.insert(item.url.absoluteString).inserted {
            dedup.append(item)
        }
        return dedup
    }
    
    func computeTotalMediaBytes(from notes: [Note]) -> Int64 {
        var total: Int64 = 0
        for note in notes {
            guard let bundle = note.bundle else { continue }
            switch bundle {
            case .media(let images, let videos):
                for imageAttachment in images { total += Int64(imageAttachment.data.count) }
                for videoAttachment in videos { total += fileSize(at: videoAttachment.url) }
            case .files(let files):
                for fileAttachment in files { total += fileSize(at: fileAttachment.url) }
            case .audio(let audios):
                for audioAttachment in audios { total += fileSize(at: audioAttachment.url) }
            }
        }
        return max(0, total)
    }
    
    func fileSize(at url: URL) -> Int64 {
        if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
            return Int64(size)
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? NSNumber {
            return size.int64Value
        }
        return 0
    }
}

// MARK: - Private - Mutations
private extension ChattingArchiveViewModel {
    func setFavorite(_ newValue: Bool) {
        isFavorite = newValue
        persistFavorite(newValue)
    }
    
    func persistFavorite(_ newValue: Bool) {
        guard let base = client else { return }
        let updated = Client(
            id: base.id,
            profile: base.profile,
            nameCardFront: base.nameCardFront,
            nameCardBack: base.nameCardBack,
            surname: base.surname,
            name: base.name,
            position: base.position,
            company: base.company,
            email: base.email,
            phoneNumber: base.phoneNumber,
            linkedinURL: base.linkedinURL,
            memo: base.memo,
            action: base.action,
            favorite: newValue,
            pin: base.pin,
            notes: base.notes
        )
        ClientsStore.shared.update(updated)
    }
    
    func deleteAllMediaDataForCurrentClient() {
        guard let clientId = client?.id else { return }
        var notes = ChatStore.shared.notes(for: clientId)
        var changed = false
        for idx in notes.indices {
            guard let bundle = notes[idx].bundle else { continue }
            switch bundle {
            case .media(_, let videos):
                for videoAttachment in videos { deleteFileIfExists(at: videoAttachment.url) }
                notes[idx].bundle = nil
                changed = true
            case .files(let files):
                for fileAttachment in files { deleteFileIfExists(at: fileAttachment.url) }
                notes[idx].bundle = nil
                changed = true
            case .audio(let audios):
                for audioAttachment in audios { deleteFileIfExists(at: audioAttachment.url) }
                notes[idx].bundle = nil
                changed = true
            }
        }
        if changed {
            notes.removeAll { $0.text == nil && $0.bundle == nil }
            ChatStore.shared.setNotes(notes, for: clientId)
            reloadMediaPreview()
        }
    }
    
    func deleteFileIfExists(at url: URL) {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: url)
        }
    }
    
    func deleteCurrentContact() {
        guard let id = client?.id else { return }
        ClientsStore.shared.remove(id)
        ChatStore.shared.setNotes([], for: id)
        DispatchQueue.main.async { self.onDeletedContact?() }
    }
}


