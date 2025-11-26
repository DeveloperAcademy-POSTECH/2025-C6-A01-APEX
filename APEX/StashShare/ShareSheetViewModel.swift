//
//  ShareSheetViewModel.swift
//  StashShare
//
//  MVVM for ShareSheetView adopting the app's ViewModelable.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

@MainActor
final class ShareSheetViewModel: ViewModelable {
    enum Action {
        case onAppear
        case setTab(Tab)
        case toggleSelect(UUID)
        case removeAttachment(ShareAttachmentItem)
        case setInputBarHeight(CGFloat)
        case setText(String)
        case send
        case close
        case search
    }
    
    enum Tab: String, CaseIterable, Identifiable {
        case contacts = "Contacts"
        case recents = "Recents"
        var id: String { rawValue }
    }
    
    // Inputs
    @Published var selectedTab: Tab = .contacts
    @Published var selectedIds: Set<UUID> = []
    @Published var inputText: String = ""
    @Published var attachments: [ShareAttachmentItem]
    @Published var inputBarHeight: CGFloat = 0
    @Published var isSearching: Bool = false
    @Published var searchText: String = ""
    
    // Data
    @Published private(set) var clients: [PClient] = []
    
    // Outputs (computed)
    var contactsFavorites: [PClient] {
        clientsFiltered
            .filter { $0.favorite }
            .sorted { "\($0.name) \($0.surname)".localizedCaseInsensitiveCompare("\($1.name) \($1.surname)") == .orderedAscending }
    }
    
    var contactsGrouped: [String: [PClient]] {
        // Match ShareView: group all contacts (including favorites) by company
        let grouped = Dictionary(grouping: clientsFiltered) { client -> String in
            let trimmed = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Ungrouped" : trimmed
        }
        var sorted: [String: [PClient]] = [:]
        for (key, list) in grouped {
            sorted[key] = list.sorted { "\($0.name) \($0.surname)".localizedCaseInsensitiveCompare("\($1.name) \($1.surname)") == .orderedAscending }
        }
        return sorted
    }
    
    var contactsCompanyKeys: [String] {
        contactsGrouped.keys.sorted { lhs, rhs in
            if lhs == "Ungrouped" { return false }
            if rhs == "Ungrouped" { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
    
    private var recentsSorted: [PClient] {
        clientsFiltered.sorted {
            let leftDate = $0.notes.max(by: { $0.uploadedAt < $1.uploadedAt })?.uploadedAt ?? .distantPast
            let rightDate = $1.notes.max(by: { $0.uploadedAt < $1.uploadedAt })?.uploadedAt ?? .distantPast
            if leftDate != rightDate { return leftDate > rightDate }
            let lhsName = "\($0.name) \($0.surname)"
            let rhsName = "\($1.name) \($1.surname)"
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
    }
    var recentsPinned: [PClient] { recentsSorted.filter { $0.pin } }
    var recentsUnpinned: [PClient] { recentsSorted.filter { !$0.pin } }
    
    var selectedClientsSorted: [PClient] {
        clients
            .filter { selectedIds.contains($0.id) }
            .sorted {
                let lhsName = "\($0.name) \($0.surname)"
                let rhsName = "\($1.name) \($1.surname)"
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            }
    }
    
    // Lifecycle / Callbacks
    var onFinished: (() -> Void)?
    
    init(attachments: [ShareAttachmentItem], onFinished: (() -> Void)?) {
        self.attachments = attachments
        self.onFinished = onFinished
    }
    
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            loadClients()
        case .setTab(let tab):
            selectedTab = tab
        case .toggleSelect(let id):
            toggleSelect(id)
        case .removeAttachment(let item):
            removeAttachment(item)
        case .setInputBarHeight(let height):
            inputBarHeight = height
        case .setText(let text):
            inputText = text
        case .send:
            sendNow()
        case .close:
            onFinished?()
        case .search:
            // Toggle search mode; clear query when closing
            if isSearching {
                searchText = ""
                isSearching = false
            } else {
                isSearching = true
            }
        }
    }
}

// MARK: - Private helpers
private extension ShareSheetViewModel {
    func loadClients() {
        clients = LocalStoreExt.shared.loadClients()
    }
    
    var clientsFiltered: [PClient] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSearching, !trimmed.isEmpty else { return clients }
        return clients.filter { matchesQuery($0, query: trimmed) }
    }
    
    func matchesQuery(_ client: PClient, query: String) -> Bool {
        // Match in full name or company (case-insensitive; works reasonably for Hangul too)
        let fullName = "\(client.name) \(client.surname)"
        if fullName.localizedCaseInsensitiveContains(query) { return true }
        if client.company.localizedCaseInsensitiveContains(query) { return true }
        return false
    }
    
    func toggleSelect(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
    
    func removeAttachment(_ item: ShareAttachmentItem) {
        attachments.removeAll { $0.id == item.id }
    }
    
    func sendNow() {
        guard !selectedIds.isEmpty else { return }
        
        let typed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let seeded = attachments.compactMap { item -> String? in
            if case let .text(text) = item.kind { return text } else { return nil }
        }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let bundle = makePersistedBundle()
        if bundle == nil && typed.isEmpty && seeded.isEmpty { return }
        
        var updated = clients
        for idx in updated.indices {
            guard selectedIds.contains(updated[idx].id) else { continue }
            var notesToAppend: [PNote] = []
            if let bundle {
                notesToAppend.append(PNote(id: UUID(), uploadedAt: Date(), text: nil, bundle: bundle))
            }
            if !seeded.isEmpty {
                notesToAppend.append(PNote(id: UUID(), uploadedAt: Date(), text: seeded, bundle: nil))
            }
            if !typed.isEmpty {
                notesToAppend.append(PNote(id: UUID(), uploadedAt: Date(), text: typed, bundle: nil))
            }
            updated[idx].notes.append(contentsOf: notesToAppend)
        }
        clients = updated
        LocalStoreExt.shared.saveClients(updated)
        onFinished?()
    }
    
    func makePersistedBundle() -> PAttachmentBundle? {
        var images: [PImageAttachment] = []
        var videos: [PVideoAttachment] = []
        var files: [PFileAttachment] = []
        var audios: [PAudioAttachment] = []
        
        for (order, item) in attachments.enumerated() {
            switch item.kind {
            case .image(let uiImage):
                let normalized = normalizeUIImageToSRGB8(uiImage, opaque: false)
                if let data = normalized.jpegData(compressionQuality: 0.9) {
                    images.append(PImageAttachment(data: data, progress: nil, orderIndex: order))
                }
            case .video(let url, _):
                if let url {
                    let copied = ensureSharedCopy(of: url, directoryName: "SharedVideos", defaultExtension: "mov")
                    videos.append(PVideoAttachment(url: copied.absoluteString, progress: nil, orderIndex: order))
                }
            case .file(let url):
                let defaultExt = url.pathExtension.isEmpty ? "dat" : url.pathExtension
                let copied = ensureSharedCopy(of: url, directoryName: "SharedFiles", defaultExtension: defaultExt)
                files.append(PFileAttachment(url: copied.absoluteString, progress: nil))
            case .audio(let url):
                let defaultExt = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
                let copied = ensureSharedCopy(of: url, directoryName: "SharedAudios", defaultExtension: defaultExt)
                audios.append(PAudioAttachment(url: copied.absoluteString, duration: assetDuration(for: copied)))
            case .text:
                break
            }
        }
        if !images.isEmpty || !videos.isEmpty { return .media(images: images, videos: videos) }
        if !files.isEmpty { return .files(files) }
        if !audios.isEmpty { return .audio(audios) }
        return nil
    }
    
    func ensureSharedCopy(of sourceURL: URL, directoryName: String, defaultExtension: String) -> URL {
        let fileManager = FileManager.default
        let baseDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.apex.StashShareExtension") ??
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
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
    
    func assetDuration(for url: URL) -> Double? {
        let asset = AVAsset(url: url)
        let seconds = asset.duration.seconds
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }
}


