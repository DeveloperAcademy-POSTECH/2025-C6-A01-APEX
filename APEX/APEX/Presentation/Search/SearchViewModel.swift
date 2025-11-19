//
//  SearchViewModel.swift
//  APEX
//
//  Created by Assistant on 11/19/25.
//

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class SearchViewModel: ViewModelable {
    enum Action {
        case onAppear
        case updateQuery(String)
        case saveRecent(String)
        case clearRecent
        case openArchiveAll(ArchiveSection)
        case openArchiveFiltered(ArchiveSection)
        case openRecord(URL)
        case dismissRecord
    }
    
    struct ArchivePushPayload: Identifiable {
        let id = UUID()
        let section: ArchiveSection
        let media: [FlattenedMediaItem]
        let files: [FlattenedFileItem]
        let links: [FlattenedLinkItem]
        let audios: [FlattenedAudioItem]
        let title: String
        let excludedClientIds: [UUID]
    }
    
    struct RecordPayload: Identifiable { let id = UUID(); let url: URL }
    
    // MARK: - Published UI State
    @Published var query: String
    @Published var recentQueries: [String] = []
    @Published var allMedia: [FlattenedMediaItem] = []
    @Published var allFiles: [FlattenedFileItem] = []
    @Published var allAudios: [FlattenedAudioItem] = []
    @Published var allLinks: [FlattenedLinkItem] = []
    @Published var archivePayload: ArchivePushPayload?
    @Published var recordPayload: RecordPayload?
    
    // MARK: - Storage
    private let recentQueriesKey = "apex.search.recentQueries"
    
    // MARK: - Init
    init(
        initialQuery: String = "",
        previewRecentQueries: [String] = [],
        previewAllMedia: [FlattenedMediaItem] = [],
        previewAllFiles: [FlattenedFileItem] = [],
        previewAllLinks: [FlattenedLinkItem] = [],
        previewAllAudios: [FlattenedAudioItem] = []
    ) {
        self.query = initialQuery
        if !previewRecentQueries.isEmpty { self.recentQueries = previewRecentQueries }
        if !previewAllMedia.isEmpty { self.allMedia = previewAllMedia }
        if !previewAllFiles.isEmpty { self.allFiles = previewAllFiles }
        if !previewAllLinks.isEmpty { self.allLinks = previewAllLinks }
        if !previewAllAudios.isEmpty { self.allAudios = previewAllAudios }
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            loadRecent()
            if allMedia.isEmpty && allFiles.isEmpty && allLinks.isEmpty && allAudios.isEmpty {
                reloadAllAggregates()
            }
            
        case .updateQuery(let new):
            query = new
            
        case .saveRecent(let text):
            saveRecent(text)
            
        case .clearRecent:
            clearRecent()
            
        case .openArchiveAll(let section):
            archivePayload = ArchivePushPayload(
                section: section,
                media: allMedia,
                files: allFiles,
                links: allLinks,
                audios: allAudios,
                title: "모든 클라이언트",
                excludedClientIds: []
            )
            
        case .openArchiveFiltered(let section):
            let filtered = filteredAggregates(for: query)
            archivePayload = ArchivePushPayload(
                section: section,
                media: filtered.media,
                files: filtered.files,
                links: filtered.links,
                audios: filtered.audios,
                title: "검색 결과",
                excludedClientIds: []
            )
            
        case .openRecord(let url):
            recordPayload = .init(url: url)
            
        case .dismissRecord:
            recordPayload = nil
        }
    }
}

// MARK: - Public Helpers for View
extension SearchViewModel {
    func filteredClients(_ queryString: String) -> [Client] {
        let trimmed = queryString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let clients = ClientsStore.shared.clients
        return clients.filter { client in
            let haystacks: [String] = [
                client.name, client.surname,
                client.company, client.position ?? "",
                client.email ?? "", client.phoneNumber ?? ""
            ]
            return haystacks.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) })
        }
    }
    
    func matchedClientNotes(_ queryString: String) -> [(Client, Note)] {
        let trimmed = queryString.trimmingCharacters(in: .whitespacesAndNewlines)
        return allClientNotes().compactMap { pair in
            let (client, note) = pair
            guard let text = note.text, !trimmed.isEmpty else { return nil }
            return text.localizedCaseInsensitiveContains(trimmed) ? (client, note) : nil
        }
    }
    
    func filteredAggregates(for queryString: String) -> (media: [FlattenedMediaItem], files: [FlattenedFileItem], links: [FlattenedLinkItem], audios: [FlattenedAudioItem]) {
        let trimmed = queryString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ([], [], [], []) }
        let noteIdsWithMatch: Set<UUID> = Set(allClientNotes().compactMap { (_, note) in
            guard let text = note.text, !trimmed.isEmpty else { return nil }
            return text.localizedCaseInsensitiveContains(trimmed) ? note.id : nil
        })
        let mediaFiltered = allMedia.filter { item in
            guard let parsed = parseFlattenedMediaId(item.id) else { return false }
            return noteIdsWithMatch.contains(parsed.noteId)
        }
        let filesFiltered = allFiles.filter { file in
            file.url.lastPathComponent.localizedCaseInsensitiveContains(trimmed)
        }
        let linksFiltered = allLinks.filter { link in
            link.url.absoluteString.localizedCaseInsensitiveContains(trimmed)
        }
        let audiosFiltered = allAudios.filter { audio in
            let base = audio.url.deletingPathExtension().lastPathComponent
            return base.localizedCaseInsensitiveContains(trimmed)
        }
        return (mediaFiltered, filesFiltered, linksFiltered, audiosFiltered)
    }
    
    func ownerForFlattenedMedia(_ item: FlattenedMediaItem) -> (client: Client, noteId: UUID)? {
        guard let parsed = parseFlattenedMediaId(item.id) else { return nil }
        for client in ClientsStore.shared.clients {
            var notesForClient = ChatStore.shared.notes(for: client.id)
            if notesForClient.isEmpty { notesForClient = client.notes }
            if notesForClient.contains(where: { $0.id == parsed.noteId }) {
                return (client, parsed.noteId)
            }
        }
        return nil
    }
    
    func mediaPayloadForClient(_ client: Client) -> (items: [MediaSource], anchors: [(noteId: UUID, isImage: Bool, localIndex: Int)]) {
        var notesForClient = ChatStore.shared.notes(for: client.id)
        if notesForClient.isEmpty { notesForClient = client.notes }
        let flattened = computeMediaItems(from: notesForClient)
        let items: [MediaSource] = flattened.map { flattenedItem in
            if flattenedItem.isVideo, let url = flattenedItem.videoURL {
                return .video(url)
            } else {
                return .image(flattenedItem.imageData ?? Data())
            }
        }
        let anchors: [(UUID, Bool, Int)] = flattened.compactMap { flattenedItem in
            guard let parsed = parseFlattenedMediaId(flattenedItem.id) else { return nil }
            return (parsed.noteId, parsed.isImage, parsed.localIndex)
        }
        return (items, anchors)
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
}

// MARK: - Private
private extension SearchViewModel {
    func loadRecent() {
        let stored = UserDefaults.standard.string(forKey: recentQueriesKey) ?? ""
        recentQueries = stored
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }
    
    func saveRecent(_ queryString: String) {
        let trimmed = queryString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var set = [trimmed] + recentQueries.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        if set.count > 12 { set = Array(set.prefix(12)) }
        recentQueries = set
        UserDefaults.standard.set(set.joined(separator: "\n"), forKey: recentQueriesKey)
    }
    
    func reloadAllAggregates() {
        let notes = allClientNotes().map { $0.1 }
        allMedia = computeMediaItems(from: notes)
        allFiles = computeFileItems(from: notes)
        allAudios = computeAudioItems(from: notes)
        allLinks = computeLinkItems(from: notes)
    }
    
    func clearRecent() {
        recentQueries = []
        UserDefaults.standard.set("", forKey: recentQueriesKey)
    }
    
    func computeMediaItems(from notes: [Note]) -> [FlattenedMediaItem] {
        var result: [FlattenedMediaItem] = []
        for note in notes {
            guard case let .media(images, videos)? = note.bundle else { continue }
            struct LocalEntry { let isImage: Bool; let index: Int; let order: Int }
            var merged: [LocalEntry] = []
            for (imageIndex, img) in images.enumerated() {
                let order = img.orderIndex ?? imageIndex
                merged.append(LocalEntry(isImage: true, index: imageIndex, order: order))
            }
            for (videoIndex, vid) in videos.enumerated() {
                let order = vid.orderIndex ?? (images.count + videoIndex)
                merged.append(LocalEntry(isImage: false, index: videoIndex, order: order))
            }
            merged.sort { $0.order < $1.order }
            for entry in merged {
                if entry.isImage {
                    result.append(.init(id: "\(note.id.uuidString)-i-\(entry.index)", isVideo: false, imageData: images[entry.index].data, videoURL: nil, uploadedAt: note.uploadedAt, localOrder: entry.order))
                } else {
                    result.append(.init(id: "\(note.id.uuidString)-v-\(entry.index)", isVideo: true, imageData: nil, videoURL: videos[entry.index].url, uploadedAt: note.uploadedAt, localOrder: entry.order))
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
    
    func urls(in text: String, limit: Int = 3) -> [URL] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let textAsNSString = text as NSString
        let fullRange = NSRange(location: 0, length: textAsNSString.length)
        let matches = detector?.matches(in: text, options: [], range: fullRange) ?? []
        var seen = Set<String>()
        var extractedURLs: [URL] = []
        for match in matches {
            guard let url = match.url else { continue }
            if seen.insert(url.absoluteString).inserted {
                extractedURLs.append(url)
                if extractedURLs.count >= limit { break }
            }
        }
        return extractedURLs
    }
    
    func allClientNotes() -> [(Client, Note)] {
        var pairs: [(Client, Note)] = []
        for client in ClientsStore.shared.clients {
            var notesForClient = ChatStore.shared.notes(for: client.id)
            if notesForClient.isEmpty {
                notesForClient = client.notes
            }
            for noteItem in notesForClient {
                pairs.append((client, noteItem))
            }
        }
        return pairs
    }
    
}


