//
//  ShareViewModel.swift
//  APEX
//
//  Created by Assistant on 11/19/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import Combine

@MainActor
final class ShareViewModel: ViewModelable {
    enum Tab: String, CaseIterable, Identifiable {
        case connects = "Connects"
        case recents = "Recents"
        var id: String { rawValue }
    }
    
    enum Action {
        case onAppear
        case setTab(Tab)
        case toggleSelect(UUID)
        case setText(String)
        case removeAttachment(ShareAttachmentItem)
        case send
        case search
    }
    
    // Inputs
    private let store: ClientsStore = .shared
    let initialAttachmentsSeed: [ShareAttachmentItem]
    let excludedIds: Set<UUID>
    
    // MARK: - UI State
    @Published var selectedTab: Tab = .connects
    @Published var selectedIds: Set<UUID> = []
    @Published var inputText: String = ""
    @Published var attachments: [ShareAttachmentItem] = []
    @Published var shouldDismiss: Bool = false
    
    // MARK: - Init
    init(
        initialAttachments: [ShareAttachmentItem] = [],
        excludedClientIds: [UUID] = []
    ) {
        self.initialAttachmentsSeed = initialAttachments
        self.excludedIds = Set(excludedClientIds)
    }
    
    // MARK: - Derived: Connects
    var connectsFavorites: [Client] {
        store.clients.filter { !excludedIds.contains($0.id) && $0.favorite }.sorted(by: sortByName)
    }
    
    var connectsGrouped: [String: [Client]] {
        let filtered = store.clients.filter { !excludedIds.contains($0.id) }
        let grouped = Dictionary(grouping: filtered) { client -> String in
            let trimmed = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Ungrouped" : trimmed
        }
        var sortedGroups: [String: [Client]] = [:]
        for (key, value) in grouped { sortedGroups[key] = value.sorted(by: sortByName) }
        return sortedGroups
    }
    
    var connectsCompanyKeys: [String] {
        connectsGrouped.keys.sorted { lhs, rhs in
            if lhs == "Ungrouped" { return false }
            if rhs == "Ungrouped" { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
    
    // MARK: - Derived: Recents
    private var recentsSorted: [Client] {
        store.clients
            .filter { !excludedIds.contains($0.id) }
            .sorted { lhs, rhs in
                let lDate = latestNoteDate(of: lhs) ?? .distantPast
                let rDate = latestNoteDate(of: rhs) ?? .distantPast
                if lDate != rDate { return lDate > rDate }
                return sortByName(lhs, rhs)
            }
    }
    
    var recentsPinned: [Client] { recentsSorted.filter { $0.pin } }
    var recentsUnpinned: [Client] { recentsSorted.filter { !$0.pin } }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            inputText = ""
            attachments = initialAttachmentsSeed
        case .setTab(let tab):
            selectedTab = tab
        case .toggleSelect(let id):
            toggleSelect(id)
        case .setText(let text):
            inputText = text
        case .removeAttachment(let item):
            removeAttachment(item)
        case .send:
            handleSend()
        case .search:
            break
        }
    }
}

// MARK: - Private helpers
private extension ShareViewModel {
    func latestNoteDate(of client: Client) -> Date? {
        client.notes.max(by: { $0.uploadedAt < $1.uploadedAt })?.uploadedAt
    }
    
    func sortByName(_ lhs: Client, _ rhs: Client) -> Bool {
        let lhsName = "\(lhs.name) \(lhs.surname)"
        let rhsName = "\(rhs.name) \(rhs.surname)"
        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
    }
    
    func toggleSelect(_ id: UUID) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }
    
    func handleSend() {
        let typed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let seeded = attachments.compactMap { item -> String? in
            if case let .text(text) = item.kind { return text } else { return nil }
        }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let bundle = makeAttachmentBundle()
        
        if selectedIds.isEmpty { return }
        if bundle == nil && seeded.isEmpty && typed.isEmpty { return }
        
        var notesToSend: [Note] = []
        if let bundle {
            notesToSend.append(Note(uploadedAt: Date(), text: nil, bundle: bundle))
        }
        if !seeded.isEmpty {
            notesToSend.append(Note(uploadedAt: Date(), text: seeded, bundle: nil))
        }
        if !typed.isEmpty {
            notesToSend.append(Note(uploadedAt: Date(), text: typed, bundle: nil))
        }
        
        for id in selectedIds {
            if let idx = store.clients.firstIndex(where: { $0.id == id }) {
                var client = store.clients[idx]
                for note in notesToSend {
                    client.notes.append(note)
                }
                store.update(client)
            }
            let existing = ChatStore.shared.notes(for: id)
            var updated = existing
            for note in notesToSend {
                updated.append(note)
            }
            ChatStore.shared.setNotes(updated, for: id)
            if SyncSettings.isAutoOn {
                for note in notesToSend {
                    CloudKitNotesManager.shared.save(note: note, for: id)
                }
            }
        }
        
        inputText = ""
        attachments.removeAll()
        selectedIds.removeAll()
        shouldDismiss = true
    }
    
    func makeAttachmentBundle() -> AttachmentBundle? {
        var images: [ImageAttachment] = []
        var videos: [VideoAttachment] = []
        var genericFiles: [URL] = []
        var audios: [URL] = []
        
        for (order, item) in attachments.enumerated() {
            switch item.kind {
            case .image(let uiImage):
                if let data = uiImage.jpegData(compressionQuality: 0.9) {
                    images.append(ImageAttachment(data: data, progress: nil, orderIndex: order))
                }
            case .video(let url, _):
                if let url {
                    let copied = ensureSharedCopy(of: url, directoryName: "SharedVideos", defaultExtension: "mov")
                    videos.append(VideoAttachment(url: copied, progress: nil, orderIndex: order))
                }
            case .file(let url):
                let type = UTType(filenameExtension: url.pathExtension)
                if let inferredType = type, inferredType.conforms(to: .image), let data = try? Data(contentsOf: url) {
                    images.append(ImageAttachment(data: data, progress: nil, orderIndex: order))
                } else if let inferredType = type, inferredType.conforms(to: .movie) || (type?.conforms(to: .audiovisualContent) ?? false) {
                    let copied = ensureSharedCopy(of: url, directoryName: "SharedVideos", defaultExtension: url.pathExtension.isEmpty ? "mov" : url.pathExtension)
                    videos.append(VideoAttachment(url: copied, progress: nil, orderIndex: order))
                } else {
                    genericFiles.append(url)
                }
            case .audio(let url):
                audios.append(url)
            case .text:
                break
            }
        }
        
        if !images.isEmpty || !videos.isEmpty {
            return .media(images: images, videos: videos)
        }
        if !genericFiles.isEmpty {
            let files = genericFiles.map { url in
                let copied = ensureSharedCopy(of: url, directoryName: "SharedFiles", defaultExtension: "dat")
                return FileAttachment(url: copied, contentType: UTType(filenameExtension: copied.pathExtension), progress: nil)
            }
            return .files(files)
        }
        if !audios.isEmpty {
            let sharedURLs: [URL] = audios.map { ensureSharedAudioCopy(of: $0) }
            let audioAttachments: [AudioAttachment] = sharedURLs.map { url in
                AudioAttachment(url: url, duration: assetDuration(for: url))
            }
            return .audio(audioAttachments)
        }
        return nil
    }
    
    func removeAttachment(_ item: ShareAttachmentItem) {
        attachments.removeAll { $0.id == item.id }
    }
}

// MARK: - File utilities (copy to shared containers)
private extension ShareViewModel {
    func ensureSharedAudioCopy(of sourceURL: URL) -> URL {
        let fileManager = FileManager.default
        let baseDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.apex.StashShareExtension") ??
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ??
            sourceURL.deletingLastPathComponent()
        let sharedDir = baseDir.appendingPathComponent("SharedAudios", isDirectory: true)
        if !fileManager.fileExists(atPath: sharedDir.path) {
            try? fileManager.createDirectory(at: sharedDir, withIntermediateDirectories: true)
        }
        let name = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        var dest = sharedDir.appendingPathComponent(name).appendingPathExtension(ext)
        var counter = 2
        while fileManager.fileExists(atPath: dest.path) {
            dest = sharedDir.appendingPathComponent("\(name) \(counter)").appendingPathExtension(ext)
            counter += 1
        }
        if sourceURL == dest { return dest }
        if fileManager.fileExists(atPath: dest.path) == false {
            try? fileManager.copyItem(at: sourceURL, to: dest)
        }
        return dest
    }
    
    func ensureSharedCopy(of sourceURL: URL, directoryName: String, defaultExtension: String) -> URL {
        let fileManager = FileManager.default
        let baseDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.apex.StashShareExtension") ??
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ??
            sourceURL.deletingLastPathComponent()
        let sharedDir = baseDir.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: sharedDir.path) {
            try? fileManager.createDirectory(at: sharedDir, withIntermediateDirectories: true)
        }
        let name = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? defaultExtension : sourceURL.pathExtension
        var dest = sharedDir.appendingPathComponent(name).appendingPathExtension(ext)
        var counter = 2
        while fileManager.fileExists(atPath: dest.path) {
            dest = sharedDir.appendingPathComponent("\(name) \(counter)").appendingPathExtension(ext)
            counter += 1
        }
        if sourceURL != dest, !fileManager.fileExists(atPath: dest.path) {
            try? fileManager.copyItem(at: sourceURL, to: dest)
        }
        return dest
    }
    
    func assetDuration(for url: URL) -> TimeInterval? {
        let asset = AVAsset(url: url)
        let seconds = asset.duration.seconds
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }
}


