//
//  NotesManagementViewModel.swift
//  APEX
//
//  Created by Assistant on 11/23/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class NotesManagementViewModel: ViewModelable {
    enum Action {
        case onAppear
        case deleteTapped
        case confirmDelete
        case cancelDelete
        case movePinned(IndexSet, Int)
        case completeTapped
    }
    
    // MARK: - Published State
    @Published var selectedNoteIds: Set<UUID> = []
    @Published var isSelectionMode: Bool = false
    @Published var selectedFilter: NotesFilter = .all
    @Published var showDeleteConfirmation: Bool = false
    @Published var notes: [NoteItem] = []
    
    // MARK: - Dependencies
    private let clientsStore = ClientsStore.shared
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Computed
    var availableFilters: [NotesFilterItem] {
        let companies = companyNames
        let all = NotesFilterItem(filter: .all, isEnabled: true)
        let companyFilters = companies.map { NotesFilterItem(filter: .company($0), isEnabled: true) }
        return [all] + companyFilters
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            bindClients()
            refreshNotesFromClients()
            
        case .deleteTapped:
            showDeleteConfirmation = true
            
        case .confirmDelete:
            deleteSelectedNotes()
            
        case .cancelDelete:
            showDeleteConfirmation = false
            
        case .movePinned(let source, let destination):
            movePinnedNote(from: source, to: destination)
            
        case .completeTapped:
            selectedNoteIds.removeAll()
            isSelectionMode = false
        }
    }
}

// MARK: - Private helpers
private extension NotesManagementViewModel {
    func bindClients() {
        // Avoid duplicate bindings
        cancellables.removeAll()
        clientsStore.$clients
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshNotesFromClients()
            }
            .store(in: &cancellables)
    }
    
    var companyNames: [String] {
        Set(clientsStore.clients.compactMap { client in
            let trimmed = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }).sorted()
    }
    
    func refreshNotesFromClients() {
        let clients = clientsStore.clients
        let pinIndices: [Int] = clients
            .filter { $0.pin }
            .compactMap { PinOrderManager.shared.getPinIndex(for: $0.id) }
        let maxPinIndex = pinIndices.max() ?? -1
        
        let mapped: [NoteItem] = clients.map { client in
            let latest = client.notes.sorted(by: { $0.uploadedAt > $1.uploadedAt }).first
            let content = summarizeContent(for: latest)
            let createdAt = latest?.uploadedAt ?? .distantPast
            let isPinned = client.pin
            let orderIndex = PinOrderManager.shared.getPinIndex(for: client.id)
            let pinOrder = (orderIndex != nil) ? (maxPinIndex - (orderIndex ?? 0)) : 0
            
            return NoteItem(
                id: client.id,
                author: client.autoFormattedName,
                content: content,
                company: client.company,
                createdAt: createdAt,
                isPinned: isPinned,
                pinOrder: pinOrder
            )
        }
        notes = mapped
    }
    
    func summarizeContent(for note: Note?) -> String {
        guard let note = note else { return "노트 없음" }
        if let text = note.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        if let bundle = note.bundle {
            switch bundle {
            case .media(let images, let videos):
                var parts: [String] = []
                if !images.isEmpty { parts.append("이미지 \(images.count)") }
                if !videos.isEmpty { parts.append("비디오 \(videos.count)") }
                return parts.isEmpty ? "미디어 첨부" : parts.joined(separator: ", ")
            case .files(let files):
                return files.isEmpty ? "파일 첨부" : "파일 \(files.count)"
            case .audio(let audios):
                return audios.isEmpty ? "오디오 첨부" : "오디오 \(audios.count)"
            }
        }
        return "노트 없음"
    }
    
    func deleteSelectedNotes() {
        for targetId in selectedNoteIds {
            if let idx = clientsStore.clients.firstIndex(where: { $0.id == targetId }) {
                let current = clientsStore.clients[idx]
                let updated = Client(
                    id: current.id,
                    profile: current.profile,
                    nameCardFront: current.nameCardFront,
                    nameCardBack: current.nameCardBack,
                    surname: current.surname,
                    name: current.name,
                    position: current.position,
                    company: current.company,
                    email: current.email,
                    phoneNumber: current.phoneNumber,
                    linkedinURL: current.linkedinURL,
                    memo: current.memo,
                    action: current.action,
                    favorite: current.favorite,
                    pin: current.pin,
                    notes: []
                )
                clientsStore.clients[idx] = updated
                ChatStore.shared.setNotes([], for: current.id)
            }
        }
        refreshNotesFromClients()
        selectedNoteIds.removeAll()
        isSelectionMode = false
        showDeleteConfirmation = false
    }
    
    func movePinnedNote(from sourceIndices: IndexSet, to destination: Int) {
        let baseNotes: [NoteItem] = notes.filter { selectedFilter.matches(company: $0.company) }
        
        let currentFilteredNotes = baseNotes.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            if lhs.isPinned && rhs.isPinned {
                return lhs.pinOrder > rhs.pinOrder
            }
            return lhs.createdAt > rhs.createdAt
        }
        
        var pinnedNotesInDisplayOrder = currentFilteredNotes.filter { $0.isPinned }
        
        guard let sourceIndex = sourceIndices.first,
              sourceIndex < pinnedNotesInDisplayOrder.count else {
            return
        }
        
        let draggedNote = pinnedNotesInDisplayOrder.remove(at: sourceIndex)
        let safeDestination = min(destination, pinnedNotesInDisplayOrder.count)
        pinnedNotesInDisplayOrder.insert(draggedNote, at: safeDestination)
        
        var globalPinnedIds: [UUID] = clientsStore.clients
            .filter { $0.pin }
            .sorted {
                let aIndex = PinOrderManager.shared.getPinIndex(for: $0.id) ?? Int.max
                let bIndex = PinOrderManager.shared.getPinIndex(for: $1.id) ?? Int.max
                if aIndex != bIndex { return aIndex < bIndex }
                return $0.id.uuidString < $1.id.uuidString
            }
            .map { $0.id }
        
        let visiblePinnedIdsNewOrder = pinnedNotesInDisplayOrder.map { $0.id }
        let visiblePositionsInGlobal: [Int] = visiblePinnedIdsNewOrder.compactMap { id in
            globalPinnedIds.firstIndex(of: id)
        }.sorted()
        
        for (positionIndex, pos) in visiblePositionsInGlobal.enumerated() where positionIndex < visiblePinnedIdsNewOrder.count {
            globalPinnedIds[pos] = visiblePinnedIdsNewOrder[positionIndex]
        }
        
        PinOrderManager.shared.reorderPins(globalPinnedIds)
        refreshNotesFromClients()
    }
}


