//
//  RecordViewModel.swift
//  APEX
//
//  Created by Assistant on 11/19/25.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine
import Speech

@MainActor
final class RecordViewModel: ViewModelable {
    enum Action {
        case onAppear
        case onDisappear
        case togglePlay
        case onScrub(Double)
        case onScrubBegan
        case onScrubEnded
        case save
        case tapShare
        case tapDelete
        case confirmDelete
        case setFilename(String)
        case setConversation(String)
        case startTranscription
    }
    
    // MARK: - Inputs
    let originalURL: URL?
    
    // MARK: - UI State
    @Published var showShareSheet: Bool = false
    @Published var filenameText: String = ""
    @Published var conversation: String = ""
    @Published var isTranscribing: Bool = false
    @Published var sttError: String?
    
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var totalTime: Double = 0
    @Published var workingURL: URL?
    
    @Published var showDeleteAlert: Bool = false
    @Published var volume: Double = 1.0
    
    // MARK: - Internals
    private var player: AVAudioPlayer?
    private var timeObserver: Timer?
    
    // MARK: - Init
    init(audioURL: URL?) {
        self.originalURL = audioURL
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            handleOnAppear()
        case .onDisappear:
            teardown()
        case .togglePlay:
            togglePlay()
        case .onScrub(let seconds):
            seek(to: seconds)
        case .onScrubBegan:
            isPlaying = false
            player?.pause()
        case .onScrubEnded:
            if player != nil {
                player?.play()
                isPlaying = true
            }
        case .save:
            saveAudio()
        case .tapShare:
            showShareSheet = true
        case .tapDelete:
            showDeleteAlert = true
        case .confirmDelete:
            confirmDelete()
        case .setFilename(let text):
            filenameText = text
        case .setConversation(let text):
            conversation = text
        case .startTranscription:
            startTranscription()
        }
    }
    
    // Public helpers
    func setVolume(_ newValue: Double) {
        volume = newValue
        player?.volume = Float(newValue)
    }
}

// MARK: - Lifecycle
private extension RecordViewModel {
    func handleOnAppear() {
        workingURL = originalURL
        setupPlayerIfNeeded()
        filenameText = defaultTitle()
        if (workingURL ?? originalURL) != nil,
           conversation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            startTranscription()
        }
    }
    
    func setupPlayerIfNeeded() {
        guard player == nil, let url = workingURL ?? originalURL else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.defaultToSpeaker])
            try? session.setActive(true)
            
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = Float(volume)
            player = audioPlayer
            totalTime = audioPlayer.duration
            startTimer()
        } catch {
            player = nil
        }
    }
    
    func startTimer() {
        timeObserver?.invalidate()
        timeObserver = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let audioPlayer = self.player else { return }
            self.currentTime = audioPlayer.currentTime
            self.totalTime = audioPlayer.duration
            if !audioPlayer.isPlaying { self.isPlaying = false }
        }
    }
    
    func teardown() {
        timeObserver?.invalidate(); timeObserver = nil
        player?.stop(); player = nil
        isPlaying = false
    }
}

// MARK: - Controls
private extension RecordViewModel {
    func togglePlay() {
        guard let audioPlayer = player else { return }
        if isPlaying {
            audioPlayer.pause()
            isPlaying = false
        } else {
            audioPlayer.play()
            isPlaying = true
        }
    }
    
    func seek(to seconds: Double) {
        guard let audioPlayer = player else { return }
        let next = max(0, min(audioPlayer.duration, seconds))
        audioPlayer.currentTime = next
        currentTime = next
    }
}

// MARK: - File Ops
private extension RecordViewModel {
    func saveAudio() {
        guard let fromURL = workingURL ?? originalURL else { return }
        let sanitized = filenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Persist edited STT to the corresponding chat note regardless of filename change
        if sanitized.isEmpty {
            // No rename attempt when filename empty, but still persist conversation text
            persistConversationToChat(oldURL: fromURL, newURL: nil)
            return
        }
        
        let currentBase = fromURL.deletingPathExtension().lastPathComponent
        let ext = fromURL.pathExtension.isEmpty ? "m4a" : fromURL.pathExtension
        let baseDir = fromURL.deletingLastPathComponent()
        
        if sanitized == currentBase {
            // Filename unchanged; still persist conversation text back to chat
            persistConversationToChat(oldURL: fromURL, newURL: nil)
            return
        }
        
        var target = baseDir.appendingPathComponent(sanitized).appendingPathExtension(ext)
        var counter = 2
        while FileManager.default.fileExists(atPath: target.path) && target != fromURL {
            target = baseDir.appendingPathComponent("\(sanitized) \(counter)").appendingPathExtension(ext)
            counter += 1
        }
        
        if target == fromURL { return }
        
        do {
            try FileManager.default.moveItem(at: fromURL, to: target)
            workingURL = target
            teardown()
            setupPlayerIfNeeded()
            filenameText = target.deletingPathExtension().lastPathComponent
            NotificationCenter.default.post(
                name: .apexAudioRenamed,
                object: nil,
                userInfo: ["oldURL": fromURL, "newURL": target]
            )
            // After a successful rename, also persist edited STT and sync the audio URL inside the note
            persistConversationToChat(oldURL: fromURL, newURL: target)
        } catch {
            // keep old name if move failed
            // Even if rename failed, still persist conversation text using original URL
            persistConversationToChat(oldURL: fromURL, newURL: nil)
        }
    }
    
    func confirmDelete() {
        guard let oldURL = workingURL ?? originalURL else { return }
        teardown()
        NotificationCenter.default.post(
            name: .apexAudioDeleted,
            object: nil,
            userInfo: ["url": oldURL]
        )
        try? FileManager.default.removeItem(at: oldURL)
    }
    
    func defaultTitle() -> String {
        guard let url = workingURL ?? originalURL else { return "음성 메모" }
        let base = url.deletingPathExtension().lastPathComponent
        return base.isEmpty ? "음성 메모" : base
    }
}

// MARK: - Duration
extension RecordViewModel {
    func resolveDuration(for url: URL) -> TimeInterval? {
        if totalTime > 0 { return totalTime }
        if let asset = assetDuration(for: url) { return asset }
        if let audioDurationPlayer = try? AVAudioPlayer(contentsOf: url) { return audioDurationPlayer.duration }
        return nil
    }
    
    private func assetDuration(for url: URL) -> TimeInterval? {
        let asset = AVAsset(url: url)
        let sec = asset.duration.seconds
        return sec.isFinite && sec > 0 ? sec : nil
    }
}

// MARK: - STT
private extension RecordViewModel {
    func startTranscription() {
        guard !isTranscribing else { return }
        guard let url = workingURL ?? originalURL else { return }
        isTranscribing = true
        sttError = nil
        
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self else { return }
            if authStatus != .authorized {
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    self.sttError = "음성 인식 권한이 필요합니다."
                }
                return
            }
            
            let koLocale = Locale(identifier: "ko-KR")
            let preferredLocale = SFSpeechRecognizer.supportedLocales().contains(koLocale) ? koLocale : Locale.current
            let recognizer = SFSpeechRecognizer(locale: preferredLocale)
            guard let recognizer = recognizer, recognizer.isAvailable else {
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    self.sttError = "음성 인식이 현재 불가능합니다."
                }
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            if #available(iOS 13.0, *) {
                request.requiresOnDeviceRecognition = false
            }
            var hints: [String] = []
            let nameHint = self.filenameText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !nameHint.isEmpty { hints.append(nameHint) }
            request.contextualStrings = hints
            
            recognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        self.conversation = result.bestTranscription.formattedString
                    }
                    if result.isFinal {
                        DispatchQueue.main.async { self.isTranscribing = false }
                    }
                }
                if let error = error {
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        self.sttError = error.localizedDescription
                    }
                }
            }
        }
    }
}

// MARK: - Sync edited STT back to Chat
private extension RecordViewModel {
    func persistConversationToChat(oldURL: URL, newURL: URL?) {
        // Push the edited conversation back into the chat note that owns this audio
        // Match by filename to be resilient to directory differences. Prefer matching oldURL (pre-rename),
        // and fall back to newURL when provided.
        let candidates: [String] = {
            var arr: [String] = [oldURL.lastPathComponent]
            if let newURL { arr.append(newURL.lastPathComponent) }
            return arr
        }()
        // Find the owning client and note by scanning current clients' notes
        var targetClientId: UUID?
        var targetNoteId: UUID?
        for client in ClientsStore.shared.clients {
            for note in client.notes {
                if case let .audio(audios) = note.bundle {
                    if audios.contains(where: { audio in
                        let name = audio.url.lastPathComponent
                        return candidates.contains(where: { $0 == name })
                    }) {
                        targetClientId = client.id
                        targetNoteId = note.id
                        break
                    }
                }
            }
            if targetClientId != nil { break }
        }
        guard let clientId = targetClientId, let noteId = targetNoteId else { return }
        
        // Update ChatStore (source of truth for open chats)
        var notes = ChatStore.shared.notes(for: clientId)
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return }
        
        // Apply edited text (allow empty to clear STT)
        notes[index].text = conversation
        
        // If the file was renamed, also update the audio URL inside the note so persistence stays consistent
        if let newURL {
            if case var .audio(audios) = notes[index].bundle {
                for i in audios.indices {
                    if audios[i].url.lastPathComponent == oldURL.lastPathComponent {
                        audios[i] = AudioAttachment(url: newURL, duration: audios[i].duration)
                    }
                }
                notes[index].bundle = .audio(audios)
            }
        }
        
        ChatStore.shared.setNotes(notes, for: clientId)
        
        // Propagate to CloudKit if available
        if SyncSettings.isAutoOn {
            CloudKitNotesManager.shared.updateText(noteId: noteId, newText: conversation)
        }
    }
}


