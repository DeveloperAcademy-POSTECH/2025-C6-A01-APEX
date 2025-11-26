//
//  ChattingViewModel.swift
//  APEX
//
//  Created by Assistant on 11/19/25.
//
import Foundation
import Combine
import SwiftUI
import AVFoundation
import Speech

@MainActor
final class ChattingViewModel: ViewModelable {
    enum Action {
        case onAppear
        case handleIncoming(Note)
        case startDeleteSelection(UUID)
        case toggleSelection(UUID)
        case performDeleteSelected
        case cancelDeleteSelection
        case deleteAudio(noteId: UUID, url: URL)
        case deleteFile(noteId: UUID, fileIndex: Int)
        case deleteMedia(anchor: ChatMessageView.ChatAnchor)
        case editNoteText(noteId: UUID, newText: String)
        case deleteNote(noteId: UUID)
        case recomputeMatches
        case navigateToNextMatch
        case navigateToPrevMatch
        case scrollToCurrentMatch
        case refreshFromStore
        case kickOffPendingUploadsIfNeeded
        case setSearchActive(Bool)
    }
    
    // Inputs
    let clientId: UUID
    let chatTitle: String
    let initialNotes: [Note]
    
    // Data
    @Published var notes: [Note] = []
    @Published var sttInProgress: Set<UUID> = []
    
    // Selection
    @Published var isDeleteSelecting: Bool = false
    @Published var selectedNoteIds: Set<UUID> = []
    
    // Search
    @Published var isSearchActive: Bool = false
    @Published var searchText: String = ""
    @Published var matchedNoteIds: [UUID] = []
    @Published var currentMatchIndex: Int = 0
    
    // Internals
    private var cancellables: Set<AnyCancellable> = []
    
    // STT queue to avoid concurrent heavy recognition tasks
    private var sttQueue: [UUID] = []
    private var isSttRunning: Bool = false
    
    // Speech auth cache to avoid repeated system prompts/work
    private var speechAuthStatus: SFSpeechRecognizerAuthorizationStatus?
    private var didRequestSpeechAuth: Bool = false
    
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
            bindNotificationsIfNeeded()
            kickOffPendingUploadsIfNeeded()
            prepareSpeechIfNeeded()
            
        case .handleIncoming(let note):
            handleIncoming(note: note)
            
        case .startDeleteSelection(let noteId):
            isDeleteSelecting = true
            selectedNoteIds = [noteId]
            
        case .toggleSelection(let noteId):
            if selectedNoteIds.contains(noteId) {
                selectedNoteIds.remove(noteId)
            } else {
                selectedNoteIds.insert(noteId)
            }
            
        case .performDeleteSelected:
            guard !selectedNoteIds.isEmpty else { return }
            // Capture IDs to delete for CloudKit sync before mutating local array
            let idsToDelete = selectedNoteIds
            notes.removeAll { idsToDelete.contains($0.id) }
            ChatStore.shared.setNotes(notes, for: clientId)
            if SyncSettings.isAutoOn {
                for noteId in idsToDelete {
                    CloudKitNotesManager.shared.delete(noteId: noteId)
                }
            }
            isDeleteSelecting = false
            selectedNoteIds.removeAll()
            
        case .cancelDeleteSelection:
            isDeleteSelecting = false
            selectedNoteIds.removeAll()
            
        case .deleteAudio(let noteId, let url):
            deleteAudio(noteId: noteId, url: url)
            
        case .deleteFile(let noteId, let fileIndex):
            deleteFile(noteId: noteId, fileIndex: fileIndex)
            
        case .deleteMedia(let anchor):
            deleteMedia(anchor: anchor)
            
        case .editNoteText(let noteId, let newText):
            if let idx = notes.firstIndex(where: { $0.id == noteId }) {
                notes[idx].text = newText
                ChatStore.shared.setNotes(notes, for: clientId)
                if SyncSettings.isAutoOn {
                    CloudKitNotesManager.shared.updateText(noteId: noteId, newText: newText)
                }
            }
            
        case .deleteNote(let noteId):
            if let idx = notes.firstIndex(where: { $0.id == noteId }) {
                notes.remove(at: idx)
                ChatStore.shared.setNotes(notes, for: clientId)
                if SyncSettings.isAutoOn {
                    CloudKitNotesManager.shared.delete(noteId: noteId)
                }
            }
            
        case .recomputeMatches:
            recomputeMatches()
            
        case .navigateToNextMatch:
            guard !matchedNoteIds.isEmpty else { return }
            currentMatchIndex = (currentMatchIndex - 1 + matchedNoteIds.count) % matchedNoteIds.count
            send(.scrollToCurrentMatch)
            
        case .navigateToPrevMatch:
            guard !matchedNoteIds.isEmpty else { return }
            currentMatchIndex = (currentMatchIndex + 1) % matchedNoteIds.count
            send(.scrollToCurrentMatch)
            
        case .scrollToCurrentMatch:
            guard !matchedNoteIds.isEmpty else { return }
            let id = matchedNoteIds[currentMatchIndex]
            NotificationCenter.default.post(name: .apexNavigateToNote, object: nil, userInfo: ["noteId": id])
            
        case .refreshFromStore:
            notes = ChatStore.shared.notes(for: clientId)
            kickOffPendingUploadsIfNeeded()
            
        case .kickOffPendingUploadsIfNeeded:
            kickOffPendingUploadsIfNeeded()
            
        case .setSearchActive(let active):
            isSearchActive = active
            if !active {
                searchText = ""
                matchedNoteIds.removeAll()
                currentMatchIndex = 0
            }
        }
    }
}

// MARK: - AttachmentBundle helpers
extension Optional where Wrapped == AttachmentBundle {
    var isNilOrEmpty: Bool {
        guard let bundle = self else { return true }
        return bundle.isEmpty
    }
}
extension AttachmentBundle {
    var isEmpty: Bool {
        switch self {
        case .media(let images, let videos):
            return images.isEmpty && videos.isEmpty
        case .files(let files):
            return files.isEmpty
        case .audio(let audios):
            return audios.isEmpty
        }
    }
}

// MARK: - Private helpers
private extension ChattingViewModel {
    func loadInitialNotes() {
        var persisted = ChatStore.shared.notes(for: clientId)
        // Normalize order on load: oldest → newest
        if !persisted.isEmpty {
            persisted.sort { $0.uploadedAt < $1.uploadedAt }
        }
        if persisted.isEmpty {
            var seeded = initialNotes
            if !seeded.isEmpty {
                seeded.sort { $0.uploadedAt < $1.uploadedAt }
            }
            // Only use initialNotes for transient display; do NOT write them back to ChatStore.
            // This avoids resurrecting notes that were deleted elsewhere (e.g., NotesView swipe delete)
            notes = seeded
            // If nothing local, attempt a lightweight CloudKit pull to repopulate chat on cold start
            if SyncSettings.isAutoOn {
                ClientsStore.shared.beginCloudSync()
                CloudKitNotesManager.shared.fetchNotes(for: clientId) { [weak self] result in
                    defer { ClientsStore.shared.endCloudSync() }
                    guard let self else { return }
                    if case .success(let fetched) = result {
                        DispatchQueue.main.async {
                            // Merge with local:
                            // 1) Preserve local STT text if CloudKit text is empty
                            // 2) Preserve local bundle if CloudKit bundle is nil/empty (avoid transient asset drop)
                            // 3) Keep local-only notes (e.g., just uploaded, not yet visible from CloudKit)
                            // Use ChatStore as source of truth (may be empty after a wipe)
                            let local = ChatStore.shared.notes(for: self.clientId)
                            var merged = fetched
                            for idx in merged.indices {
                                if let lidx = local.firstIndex(where: { $0.id == merged[idx].id }) {
                                    let localText = local[lidx].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                    let cloudText = merged[idx].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                    if !localText.isEmpty && cloudText.isEmpty {
                                        merged[idx].text = local[lidx].text
                                    }
                                    if merged[idx].bundle.isNilOrEmpty, let localBundle = local[lidx].bundle, !localBundle.isEmpty {
                                        merged[idx].bundle = localBundle
                                    }
                                }
                            }
                            for localNote in local where !merged.contains(where: { $0.id == localNote.id }) {
                                merged.append(localNote)
                            }
                            let sorted = merged.sorted { $0.uploadedAt < $1.uploadedAt }
                            self.notes = sorted
                            ChatStore.shared.setNotes(sorted, for: self.clientId)
                        }
                    }
                }
            }
        } else {
            notes = persisted
        }
    }
    
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
            let videosWithProgress = videos.map {
                VideoAttachment(url: $0.url, progress: 0, orderIndex: $0.orderIndex)
            }
            noteWithProgress.bundle = .media(images: imagesWithProgress, videos: videosWithProgress)
        } else if case let .files(files) = note.bundle {
            if files.count > 1 {
                let baseDate = note.uploadedAt
                if let text = note.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                    let textOnly = Note(uploadedAt: baseDate, text: text, bundle: nil)
                    notes.append(textOnly)
                    // Persist the text-only note to CloudKit as well
                    if SyncSettings.isAutoOn {
                        CloudKitNotesManager.shared.save(note: textOnly, for: clientId)
                    }
                }
                let startIdx = notes.count
                for fileAttachment in files {
                    let single = Note(
                        uploadedAt: baseDate,
                        text: nil,
                        bundle: .files([
                            FileAttachment(url: fileAttachment.url, contentType: fileAttachment.contentType, progress: 0)
                        ])
                    )
                    notes.append(single)
                    // Persist each split file note to CloudKit
                    if SyncSettings.isAutoOn {
                        CloudKitNotesManager.shared.save(note: single, for: clientId)
                    }
                }
                ChatStore.shared.setNotes(notes, for: clientId)
                for idx in startIdx..<notes.count {
                    startUploadsForNote(at: idx)
                }
                return
            } else if files.count == 1, let firstFile = files.first {
                noteWithProgress.bundle = .files([FileAttachment(url: firstFile.url, contentType: firstFile.contentType, progress: 0)])
            }
        }
        notes.append(noteWithProgress)
        ChatStore.shared.setNotes(notes, for: clientId)
        if let idx = notes.indices.last { startUploadsForNote(at: idx) }
        // CloudKit: save note + assets
        if SyncSettings.isAutoOn {
            CloudKitNotesManager.shared.save(note: noteWithProgress, for: clientId)
        }
        // Kick off STT for audio notes so that STT appears under the tile in chat
        if let idx = notes.indices.last {
            // Enqueue STT by noteId to process serially and avoid UI jank
            enqueueSttForNoteIfAudio(noteId: notes[idx].id)
        }
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
        // CloudKit: reflect audio deletion
        if SyncSettings.isAutoOn {
            if notes.indices.contains(idx) {
                CloudKitNotesManager.shared.rewriteAssets(noteId: noteId, bundle: notes[idx].bundle)
            } else {
                CloudKitNotesManager.shared.delete(noteId: noteId)
            }
        }
    }
    
    func deleteMedia(anchor: ChatMessageView.ChatAnchor) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == anchor.noteId }) else { return }
        guard case var .media(images, videos) = notes[noteIndex].bundle else { return }
        
        if anchor.isImage {
            guard images.indices.contains(anchor.localIndex) else { return }
            images.remove(at: anchor.localIndex)
        } else {
            guard videos.indices.contains(anchor.localIndex) else { return }
            // Remove local video file as well
            let url = videos[anchor.localIndex].url
            videos.remove(at: anchor.localIndex)
            try? FileManager.default.removeItem(at: url)
        }
        
        if images.isEmpty && videos.isEmpty {
            if notes[noteIndex].text == nil {
                notes.remove(at: noteIndex)
            } else {
                notes[noteIndex].bundle = nil
            }
            ChatStore.shared.setNotes(notes, for: clientId)
            if SyncSettings.isAutoOn {
                CloudKitNotesManager.shared.rewriteAssets(noteId: anchor.noteId, bundle: notes.indices.contains(noteIndex) ? notes[noteIndex].bundle : nil)
            }
            return
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
        
        notes[noteIndex].bundle = .media(images: images, videos: videos)
        ChatStore.shared.setNotes(notes, for: clientId)
        if SyncSettings.isAutoOn {
            CloudKitNotesManager.shared.rewriteAssets(noteId: anchor.noteId, bundle: notes[noteIndex].bundle)
        }
    }
    
    func deleteFile(noteId: UUID, fileIndex: Int) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .files(files) = notes[noteIndex].bundle else { return }
        guard files.indices.contains(fileIndex) else { return }
        // Remove local file
        let url = files[fileIndex].url
        files.remove(at: fileIndex)
        try? FileManager.default.removeItem(at: url)
        if files.isEmpty {
            if notes[noteIndex].text == nil {
                notes.remove(at: noteIndex)
            } else {
                notes[noteIndex].bundle = nil
            }
        } else {
            notes[noteIndex] = Note(uploadedAt: notes[noteIndex].uploadedAt, text: notes[noteIndex].text, bundle: .files(files))
        }
        ChatStore.shared.setNotes(notes, for: clientId)
        if SyncSettings.isAutoOn {
            CloudKitNotesManager.shared.rewriteAssets(noteId: noteId, bundle: notes.indices.contains(noteIndex) ? notes[noteIndex].bundle : nil)
        }
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
    
    // MARK: - STT for audio notes (serialized)
    func enqueueSttForNoteIfAudio(noteId: UUID) {
        // Skip if already has text
        if let idx = notes.firstIndex(where: { $0.id == noteId }) {
            let existing = notes[idx].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !existing.isEmpty { return }
            if case .audio = notes[idx].bundle {
                if !sttInProgress.contains(noteId) && !sttQueue.contains(noteId) {
                    // Mark as in-progress immediately so UI can show typing indicator
                    sttInProgress.insert(noteId)
                    sttQueue.append(noteId)
                    runNextSttIfNeeded()
                }
            }
        }
    }
    
    private func runNextSttIfNeeded() {
        guard !isSttRunning, let next = sttQueue.first else { return }
        isSttRunning = true
        performStt(noteId: next)
    }
    
    private func finishStt(noteId: UUID) {
        sttInProgress.remove(noteId)
        if !sttQueue.isEmpty, sttQueue.first == noteId {
            sttQueue.removeFirst()
        } else {
            sttQueue.removeAll { $0 == noteId }
        }
        isSttRunning = false
        runNextSttIfNeeded()
    }
    
    private func performStt(noteId: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { finishStt(noteId: noteId); return }
        guard case let .audio(audios) = notes[index].bundle, let first = audios.first else { finishStt(noteId: noteId); return }
        let url = first.url
        // Avoid duplicate work if text already exists
        if let existing = notes[index].text, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finishStt(noteId: noteId); return
        }
        // Mark STT as in progress for placeholder rendering
        sttInProgress.insert(noteId)
        
        // Ensure speech auth is determined once
        prepareSpeechIfNeeded()
        guard speechAuthStatus == .authorized else { finishStt(noteId: noteId); return }
        
        // Start recognition off main with a tiny delay to let UI settle
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            let ko = Locale(identifier: "ko-KR")
            let preferredLocale = SFSpeechRecognizer.supportedLocales().contains(ko) ? ko : Locale.current
            guard let recognizer = SFSpeechRecognizer(locale: preferredLocale), recognizer.isAvailable else { self.finishStt(noteId: noteId); return }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.taskHint = .dictation
            if #available(iOS 13.0, *) {
                request.requiresOnDeviceRecognition = false
            }
            var hints: [String] = []
            let base = url.deletingPathExtension().lastPathComponent
            if !base.isEmpty { hints.append(base) }
            request.contextualStrings = hints
            
            recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result = result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        if let idx = self.notes.firstIndex(where: { $0.id == noteId }) {
                            self.notes[idx].text = text
                            ChatStore.shared.setNotes(self.notes, for: self.clientId)
                            if SyncSettings.isAutoOn {
                                self.updateSTTToCloudKitEventually(noteId: noteId, text: text, attempt: 0)
                            }
                        }
                        self.finishStt(noteId: noteId)
                    }
                    return
                }
                if error != nil {
                    DispatchQueue.main.async {
                        self.finishStt(noteId: noteId)
                    }
                }
            }
        }
    }

    // MARK: - Speech prep
    private func prepareSpeechIfNeeded() {
        guard !didRequestSpeechAuth else { return }
        didRequestSpeechAuth = true
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            self?.speechAuthStatus = status
        }
    }
    
    private func updateSTTToCloudKitEventually(noteId: UUID, text: String, attempt: Int) {
        let maxAttempts = 20
        if CloudKitNotesManager.shared.hasRecord(for: noteId) {
            CloudKitNotesManager.shared.updateText(noteId: noteId, newText: text)
            return
        }
        guard attempt < maxAttempts else { return }
        let delay: TimeInterval = 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.updateSTTToCloudKitEventually(noteId: noteId, text: text, attempt: attempt + 1)
        }
    }
    
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
    
    func bindNotificationsIfNeeded() {
        cancellables.removeAll()
        
        NotificationCenter.default.publisher(for: .apexAudioRenamed)
            .sink { [weak self] notif in
                guard let self else { return }
                guard let oldURL = notif.userInfo?["oldURL"] as? URL,
                      let newURL = notif.userInfo?["newURL"] as? URL else { return }
                for idx in notes.indices {
                    if case var .audio(audios) = notes[idx].bundle {
                        var changed = false
                for audioIndex in audios.indices {
                    if audios[audioIndex].url == oldURL {
                        audios[audioIndex] = AudioAttachment(url: newURL, duration: audios[audioIndex].duration, displayName: audios[audioIndex].displayName)
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
                var changedNoteIds: Set<UUID> = []
                var removedNoteIds: Set<UUID> = []
                for idx in notes.indices {
                    if case var .audio(audios) = notes[idx].bundle {
                        let before = audios.count
                        audios.removeAll { $0.url == url }
                        if audios.count != before {
                            notes[idx].bundle = audios.isEmpty ? nil : .audio(audios)
                            changedAny = true
                            let noteId = notes[idx].id
                            if audios.isEmpty, notes[idx].text == nil {
                                removedNoteIds.insert(noteId)
                            } else {
                                changedNoteIds.insert(noteId)
                            }
                        }
                    }
                }
                if changedAny {
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
        
        NotificationCenter.default.publisher(for: .apexChatNotesUpdated)
            .sink { [weak self] notif in
                guard let self else { return }
                if let changedId = notif.userInfo?["clientId"] as? UUID, changedId == clientId {
                    notes = ChatStore.shared.notes(for: clientId)
                    kickOffPendingUploadsIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        // CloudKit push → fetch notes for this client and refresh UI
        NotificationCenter.default.publisher(for: .cloudKitDatabaseDidChange)
            .sink { [weak self] _ in
                guard let self else { return }
                guard SyncSettings.isAutoOn else { return }
                ClientsStore.shared.beginCloudSync()
                CloudKitNotesManager.shared.fetchNotes(for: self.clientId) { result in
                    defer { ClientsStore.shared.endCloudSync() }
                    if case .success(let fetched) = result {
                        DispatchQueue.main.async {
                            // Merge with local:
                            // 1) Keep existing STT text if fetched is empty
                            // 2) Preserve local bundle if fetched bundle is nil/empty
                            // 3) Include local-only notes not yet in CloudKit results to avoid drops
                            // Use ChatStore as the local source to respect wipes/clears done outside this view
                            let local = ChatStore.shared.notes(for: self.clientId)
                            var merged = fetched
                            for idx in merged.indices {
                                if let lidx = local.firstIndex(where: { $0.id == merged[idx].id }) {
                                    let localText = local[lidx].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                    let cloudText = merged[idx].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                    if !localText.isEmpty && cloudText.isEmpty {
                                        merged[idx].text = local[lidx].text
                                    }
                                    if merged[idx].bundle.isNilOrEmpty, let localBundle = local[lidx].bundle, !localBundle.isEmpty {
                                        merged[idx].bundle = localBundle
                                    }
                                }
                            }
                            for localNote in local where !merged.contains(where: { $0.id == localNote.id }) {
                                merged.append(localNote)
                            }
                            let sorted = merged.sorted { $0.uploadedAt < $1.uploadedAt }
                            self.notes = sorted
                            ChatStore.shared.setNotes(sorted, for: self.clientId)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
}


