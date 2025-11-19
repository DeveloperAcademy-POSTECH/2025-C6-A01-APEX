//
//  ChattingViewModel.swift
//  APEX
//
//  Created by Assistant on 11/19/25.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import UniformTypeIdentifiers
import UIKit

@MainActor
final class ChattingViewModel: ViewModelable {
    enum Action {
        case onAppear
        
        // Search
        case setSearchActive(Bool)
        case setSearchText(String)
        case navigateToNextMatch
        case navigateToPrevMatch
        case resetSearch
        
        // Edit
        case startEdit(noteId: UUID, currentText: String)
        case saveEdit(noteId: UUID, text: String)
        case cancelEdit
        case deleteNote(UUID)
        
        // Selection delete
        case startDeleteSelection(preselect: UUID?)
        case toggleSelection(UUID)
        case performDeleteSelected
        case cancelDeleteSelection
        
        // Incoming/send
        case handleIncoming(Note)
        
        // Mutations
        case deleteMedia(anchor: ChatMessageView.ChatAnchor)
        case deleteFile(noteId: UUID, fileIndex: Int)
        case deleteAudio(noteId: UUID, url: URL)
        
        // Share / Copy
        case openShare(text: String?)
        case openShareFiles([URL])
        case openShareAudio(URL)
        case setShowCopyToast(Bool)
        case copyText(String)
        
        // Record
        case openRecord(URL)
        case dismissRecord
        
        // Date picker
        case setShowDatePicker(Bool)
        case setDatePickerSelection(Date)
        case selectDate(Date)
    }
    
    struct EditingPayload: Identifiable {
        let id = UUID()
        let noteId: UUID
        var text: String
    }
    
    struct ShareSeed: Identifiable {
        let id = UUID()
        var text: String?
        var files: [URL]
        var audios: [URL]
        var images: [UIImage] = []
        var videos: [URL] = []
    }
    
    struct RecordPayload: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    // Inputs
    let clientId: UUID
    let chatTitle: String
    let initialNotes: [Note]
    
    // UI/Data State
    @Published var notes: [Note] = []
    
    // Search
    @Published var isSearchActive: Bool = false
    @Published var searchText: String = ""
    @Published var matchedNoteIds: [UUID] = []
    @Published var currentMatchIndex: Int = 0
    @Published var highlightedDate: Date?
    @Published var showDatePicker: Bool = false
    @Published var datePickerSelection: Date = Date()
    
    // Edit
    @Published var editing: EditingPayload?
    
    // Selection delete
    @Published var isDeleteSelecting: Bool = false
    @Published var selectedNoteIds: Set<UUID> = []
    
    // Share/Copy/Record
    @Published var shareSeed: ShareSeed?
    @Published var showCopyToast: Bool = false
    @Published var recordPayload: RecordPayload?
    
    // Internals
    private var cancellables: Set<AnyCancellable> = []
    
    init(clientId: UUID, chatTitle: String, initialNotes: [Note]) {
        self.clientId = clientId
        self.chatTitle = chatTitle
        self.initialNotes = initialNotes
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            loadInitialNotes()
            bindNotifications()
            kickOffPendingUploadsIfNeeded()
            
        case .setSearchActive(let active):
            isSearchActive = active
            if active == false {
                send(.resetSearch)
            }
            
        case .setSearchText(let text):
            searchText = text
            recomputeMatches()
            scrollToCurrentMatch()
            
        case .navigateToNextMatch:
            guard !matchedNoteIds.isEmpty else { return }
            currentMatchIndex = (currentMatchIndex - 1 + matchedNoteIds.count) % matchedNoteIds.count
            scrollToCurrentMatch()
            
        case .navigateToPrevMatch:
            guard !matchedNoteIds.isEmpty else { return }
            currentMatchIndex = (currentMatchIndex + 1) % matchedNoteIds.count
            scrollToCurrentMatch()
            
        case .resetSearch:
            searchText = ""
            matchedNoteIds.removeAll()
            currentMatchIndex = 0
            highlightedDate = nil
            showDatePicker = false
            
        case .startEdit(let noteId, let currentText):
            editing = .init(noteId: noteId, text: currentText)
            
        case .saveEdit(let noteId, let text):
            if let idx = notes.firstIndex(where: { $0.id == noteId }) {
                notes[idx].text = text
                ChatStore.shared.setNotes(notes, for: clientId)
            }
            editing = nil
            
        case .cancelEdit:
            editing = nil
            
        case .deleteNote(let noteId):
            if let idx = notes.firstIndex(where: { $0.id == noteId }) {
                notes.remove(at: idx)
                ChatStore.shared.setNotes(notes, for: clientId)
            }
            
        case .startDeleteSelection(let preselect):
            isDeleteSelecting = true
            selectedNoteIds = []
            if let id = preselect { selectedNoteIds.insert(id) }
            
        case .toggleSelection(let noteId):
            if selectedNoteIds.contains(noteId) {
                selectedNoteIds.remove(noteId)
            } else {
                selectedNoteIds.insert(noteId)
            }
            
        case .performDeleteSelected:
            guard !selectedNoteIds.isEmpty else { return }
            notes.removeAll { selectedNoteIds.contains($0.id) }
            ChatStore.shared.setNotes(notes, for: clientId)
            isDeleteSelecting = false
            selectedNoteIds.removeAll()
            
        case .cancelDeleteSelection:
            isDeleteSelecting = false
            selectedNoteIds.removeAll()
            
        case .handleIncoming(let note):
            handleIncoming(note: note)
            
        case .deleteMedia(let anchor):
            deleteMedia(anchor: anchor)
            
        case .deleteFile(let noteId, let fileIndex):
            deleteFile(noteId: noteId, fileIndex: fileIndex)
            
        case .deleteAudio(let noteId, let url):
            deleteAudio(noteId: noteId, url: url)
            
        case .openShare(let text):
            shareSeed = .init(text: text, files: [], audios: [])
            
        case .openShareFiles(let urls):
            shareSeed = .init(text: nil, files: urls, audios: [])
            
        case .openShareAudio(let url):
            shareSeed = .init(text: nil, files: [], audios: [url])
            
        case .setShowCopyToast(let show):
            withAnimation { showCopyToast = show }
            
        case .copyText(let text):
            UIPasteboard.general.string = text
            withAnimation { showCopyToast = true }
            
        case .openRecord(let url):
            NotificationCenter.default.post(name: .apexStopAllAudioPlayback, object: nil)
            recordPayload = .init(url: url)
            
        case .dismissRecord:
            recordPayload = nil
            
        case .setShowDatePicker(let show):
            showDatePicker = show
            if show { datePickerSelection = Date() }
            
        case .setDatePickerSelection(let date):
            datePickerSelection = date
            
        case .selectDate(let date):
            showDatePicker = false
            highlightedDate = date
            NotificationCenter.default.post(name: .apexNavigateToDate, object: nil, userInfo: ["date": date])
        }
    }
}

// MARK: - Public helpers for View
extension ChattingViewModel {
    func buildGlobalViewerPayload(startingFrom anchor: ChatMessageView.ChatAnchor) -> (items: [MediaSource], anchors: [ChatMessageView.ChatAnchor], index: Int) {
        var allItems: [MediaSource] = []
        var allAnchors: [ChatMessageView.ChatAnchor] = []
        for noteItem in notes {
            if case let .media(images, videos) = noteItem.bundle {
                struct Combined { let isImage: Bool; let index: Int; let order: Int }
                var merged: [Combined] = []
                for imageIndex in images.indices {
                    let order = images[imageIndex].orderIndex ?? imageIndex
                    merged.append(Combined(isImage: true, index: imageIndex, order: order))
                }
                for videoIndex in videos.indices {
                    let order = videos[videoIndex].orderIndex ?? (images.count + videoIndex)
                    merged.append(Combined(isImage: false, index: videoIndex, order: order))
                }
                merged.sort { $0.order < $1.order }
                for entry in merged {
                    if entry.isImage {
                        allItems.append(.image(images[entry.index].data))
                        allAnchors.append(.init(noteId: noteItem.id, isImage: true, localIndex: entry.index))
                    } else {
                        allItems.append(.video(videos[entry.index].url))
                        allAnchors.append(.init(noteId: noteItem.id, isImage: false, localIndex: entry.index))
                    }
                }
            }
        }
        let start = allAnchors.firstIndex(where: { $0.noteId == anchor.noteId && $0.isImage == anchor.isImage && $0.localIndex == anchor.localIndex }) ?? 0
        return (items: allItems, anchors: allAnchors, index: start)
    }
}

// MARK: - Private - Data loading and notifications
private extension ChattingViewModel {
    func loadInitialNotes() {
        if notes.isEmpty {
            let persisted = ChatStore.shared.notes(for: clientId)
            if persisted.isEmpty {
                notes = initialNotes
                ChatStore.shared.setNotes(initialNotes, for: clientId)
            } else {
                notes = persisted
            }
        }
    }
    
    func bindNotifications() {
        cancellables.removeAll()
        
        NotificationCenter.default.publisher(for: .apexChatNotesUpdated)
            .sink { [weak self] notif in
                guard let self else { return }
                if let changedId = notif.userInfo?["clientId"] as? UUID, changedId == self.clientId {
                    let latest = ChatStore.shared.notes(for: self.clientId)
                    self.notes = latest
                    self.kickOffPendingUploadsIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .apexAudioRenamed)
            .sink { [weak self] notif in
                guard let self else { return }
                guard let oldURL = notif.userInfo?["oldURL"] as? URL,
                      let newURL = notif.userInfo?["newURL"] as? URL else { return }
                for idx in notes.indices {
                    if case var .audio(audios) = notes[idx].bundle {
                        var changed = false
                        for i in audios.indices {
                            if audios[i].url == oldURL {
                                audios[i] = AudioAttachment(url: newURL, duration: audios[i].duration)
                                changed = true
                            }
                        }
                        if changed {
                            notes[idx].bundle = .audio(audios)
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .apexAudioDeleted)
            .sink { [weak self] notif in
                guard let self else { return }
                guard let url = notif.userInfo?["url"] as? URL else { return }
                var changedAny = false
                for idx in notes.indices {
                    if case var .audio(audios) = notes[idx].bundle {
                        let before = audios.count
                        audios.removeAll { $0.url == url }
                        if audios.count != before {
                            notes[idx].bundle = audios.isEmpty ? nil : .audio(audios)
                            changedAny = true
                        }
                    }
                }
                if changedAny {
                    ChatStore.shared.setNotes(notes, for: clientId)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Private - Mutations and uploads
private extension ChattingViewModel {
    func handleIncoming(note: Note) {
        var noteWithProgress = note
        if case let .media(images, videos) = note.bundle {
            let imagesWithProgress = images.map {
                ImageAttachment(
                    data: $0.data,
                    progress: 0,
                    orderIndex: $0.orderIndex
                )
            }
            let videosWithProgress = videos.map { VideoAttachment(url: $0.url, progress: 0, orderIndex: $0.orderIndex) }
            noteWithProgress.bundle = .media(images: imagesWithProgress, videos: videosWithProgress)
        } else if case let .files(files) = note.bundle {
            if files.count > 1 {
                let baseDate = note.uploadedAt
                if let text = note.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                    let textOnly = Note(uploadedAt: baseDate, text: text, bundle: nil)
                    notes.append(textOnly)
                }
                let startIdx = notes.count
                for f in files {
                    let single = Note(
                        uploadedAt: baseDate,
                        text: nil,
                        bundle: .files([
                            FileAttachment(url: f.url, contentType: f.contentType, progress: 0)
                        ])
                    )
                    notes.append(single)
                }
                ChatStore.shared.setNotes(notes, for: clientId)
                for idx in startIdx..<notes.count {
                    startUploadsForNote(at: idx)
                }
                return
            } else if files.count == 1, let f = files.first {
                noteWithProgress.bundle = .files([FileAttachment(url: f.url, contentType: f.contentType, progress: 0)])
            }
        }
        notes.append(noteWithProgress)
        ChatStore.shared.setNotes(notes, for: clientId)
        if let idx = notes.indices.last { startUploadsForNote(at: idx) }
    }
    
    func startUploadsForNote(at index: Int) {
        guard notes.indices.contains(index) else { return }
        let noteId = notes[index].id
        if case let .media(images, videos) = notes[index].bundle {
            for imageIndex in images.indices { simulateImageUpload(noteId: noteId, imageIndex: imageIndex) }
            for videoIndex in videos.indices { simulateVideoUpload(noteId: noteId, videoIndex: videoIndex) }
        } else if case let .files(files) = notes[index].bundle {
            for fileIndex in files.indices { simulateFileUpload(noteId: noteId, fileIndex: fileIndex) }
        }
    }
    
    func simulateImageUpload(noteId: UUID, imageIndex: Int) {
        Task { @MainActor in
            let steps = 20
            for step in 0...steps {
                setImageProgress(noteId: noteId, imageIndex: imageIndex, value: Double(step) / Double(steps))
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
            setImageProgress(noteId: noteId, imageIndex: imageIndex, value: nil)
        }
    }
    
    func simulateVideoUpload(noteId: UUID, videoIndex: Int) {
        Task { @MainActor in
            let steps = 30
            for step in 0...steps {
                setVideoProgress(noteId: noteId, videoIndex: videoIndex, value: Double(step) / Double(steps))
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            setVideoProgress(noteId: noteId, videoIndex: videoIndex, value: nil)
        }
    }
    
    func simulateFileUpload(noteId: UUID, fileIndex: Int) {
        Task { @MainActor in
            let steps = 25
            for step in 0...steps {
                setFileProgress(noteId: noteId, fileIndex: fileIndex, value: Double(step) / Double(steps))
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            setFileProgress(noteId: noteId, fileIndex: fileIndex, value: nil)
        }
    }
    
    func setImageProgress(noteId: UUID, imageIndex: Int, value: Double?) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .media(images, videos) = notes[idx].bundle, images.indices.contains(imageIndex) else { return }
        images[imageIndex].progress = value
        notes[idx].bundle = .media(images: images, videos: videos)
    }
    
    func setVideoProgress(noteId: UUID, videoIndex: Int, value: Double?) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .media(images, videos) = notes[idx].bundle, videos.indices.contains(videoIndex) else { return }
        videos[videoIndex].progress = value
        notes[idx].bundle = .media(images: images, videos: videos)
    }
    
    func setFileProgress(noteId: UUID, fileIndex: Int, value: Double?) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .files(files) = notes[idx].bundle, files.indices.contains(fileIndex) else { return }
        files[fileIndex].progress = value
        notes[idx].bundle = .files(files)
    }
    
    func hasPendingProgress(at index: Int) -> Bool {
        guard notes.indices.contains(index) else { return false }
        switch notes[index].bundle {
        case .media(let images, let videos):
            return images.contains { $0.progress != nil } || videos.contains { $0.progress != nil }
        case .files(let files):
            return files.contains { $0.progress != nil }
        default:
            return false
        }
    }
    
    func kickOffPendingUploadsIfNeeded() {
        for idx in notes.indices where hasPendingProgress(at: idx) {
            startUploadsForNote(at: idx)
        }
    }
    
    func deleteAudio(noteId: UUID, url: URL) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .audio(audios) = notes[idx].bundle else { return }
        audios.removeAll { $0.url == url }
        try? FileManager.default.removeItem(at: url)
        if audios.isEmpty {
            if notes[idx].text == nil {
                notes.remove(at: idx)
            } else {
                notes[idx].bundle = nil
            }
        } else {
            notes[idx].bundle = .audio(audios)
        }
        ChatStore.shared.setNotes(notes, for: clientId)
    }
    
    func deleteMedia(anchor: ChatMessageView.ChatAnchor) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == anchor.noteId }) else { return }
        guard case var .media(images, videos) = notes[noteIndex].bundle else { return }
        
        if anchor.isImage {
            guard images.indices.contains(anchor.localIndex) else { return }
            images.remove(at: anchor.localIndex)
        } else {
            guard videos.indices.contains(anchor.localIndex) else { return }
            videos.remove(at: anchor.localIndex)
        }
        
        if images.isEmpty && videos.isEmpty {
            if notes[noteIndex].text == nil {
                notes.remove(at: noteIndex)
            } else {
                notes[noteIndex].bundle = nil
            }
            ChatStore.shared.setNotes(notes, for: clientId)
            return
        }
        
        struct Combined { let isImage: Bool; let idx: Int; let order: Int }
        var merged: [Combined] = []
        for i in images.indices {
            let order = images[i].orderIndex ?? i
            merged.append(Combined(isImage: true, idx: i, order: order))
        }
        for v in videos.indices {
            let order = videos[v].orderIndex ?? (images.count + v)
            merged.append(Combined(isImage: false, idx: v, order: order))
        }
        merged.sort { $0.order < $1.order }
        for (newOrder, entry) in merged.enumerated() {
            if entry.isImage { images[entry.idx].orderIndex = newOrder } else { videos[entry.idx].orderIndex = newOrder }
        }
        
        notes[noteIndex].bundle = .media(images: images, videos: videos)
        ChatStore.shared.setNotes(notes, for: clientId)
    }
    
    func deleteFile(noteId: UUID, fileIndex: Int) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .files(files) = notes[noteIndex].bundle else { return }
        guard files.indices.contains(fileIndex) else { return }
        files.remove(at: fileIndex)
        if files.isEmpty {
            if notes[noteIndex].text == nil {
                notes.remove(at: noteIndex)
            } else {
                notes[noteIndex].bundle = nil
            }
        } else {
            notes[noteIndex].bundle = .files(files)
        }
        ChatStore.shared.setNotes(notes, for: clientId)
    }
}

// MARK: - Private - Search
private extension ChattingViewModel {
    func recomputeMatches() {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            matchedNoteIds.removeAll()
            currentMatchIndex = 0
            return
        }
        let lowercasedQuery = trimmedQuery.lowercased()
        var results: [UUID] = []
        for note in notes.reversed() {
            var matched = false
            if let textLowercased = note.text?.lowercased(), textLowercased.contains(lowercasedQuery) {
                matched = true
            }
            if !matched, case let .files(files) = note.bundle {
                if files.contains(where: { $0.url.lastPathComponent.lowercased().contains(lowercasedQuery) }) {
                    matched = true
                }
            }
            if !matched, case let .audio(audios) = note.bundle {
                if audios.contains(where: { $0.url.deletingPathExtension().lastPathComponent.lowercased().contains(lowercasedQuery) }) {
                    matched = true
                }
            }
            if matched { results.append(note.id) }
        }
        matchedNoteIds = results
        currentMatchIndex = results.isEmpty ? 0 : 0
    }
    
    func scrollToCurrentMatch() {
        guard !matchedNoteIds.isEmpty else { return }
        let id = matchedNoteIds[currentMatchIndex]
        NotificationCenter.default.post(name: .apexNavigateToNote, object: nil, userInfo: ["noteId": id])
    }
}
