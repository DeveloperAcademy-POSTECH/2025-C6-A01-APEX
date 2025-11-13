//
//  NotesManagementView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesManagementView: View {
    @EnvironmentObject private var router: NavigationRouter
    @ObservedObject private var clientsStore = ClientsStore.shared
    @State private var selectedNoteIds: Set<UUID> = []
    @State private var isSelectionMode: Bool = false
    @State private var selectedFilter: NotesFilter = .all
    @State private var showDeleteConfirmation = false
    @State private var notes: [NoteItem] = []
    
    var body: some View {
        ZStack {
            mainContent
            
            if showDeleteConfirmation {
                deleteConfirmationOverlay
            }
        }
        .background(Color("Background"))
        .safeAreaInset(edge: .top) {
            NotesManagementNavigationBar(
                isSelectionMode: isSelectionMode,
                onClose: { router.pop() },
                onComplete: {
                    if isSelectionMode {
                        selectedNoteIds.removeAll()
                        isSelectionMode = false
                    } else {
                        router.pop()
                    }
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            refreshNotesFromClients()
        }
        .onReceive(clientsStore.$clients) { _ in
            refreshNotesFromClients()
        }
    }
    
    private var mainContent: some View {
        NotesManagementListSection(
            selectedFilter: $selectedFilter,
            selectedNoteIds: $selectedNoteIds,
            isSelectionMode: $isSelectionMode,
            notes: $notes,
            availableFilters: availableFilters,
            onDeleteTap: {
                showDeleteConfirmation = true
            },
            onMovePinnedNote: movePinnedNote
        )
    }
    
    private var deleteConfirmationOverlay: some View {
        NotesManagementDeleteConfirmationOverlay(
            isVisible: $showDeleteConfirmation,
            selectedCount: selectedNoteIds.count,
            onConfirm: deleteSelectedNotes,
            onCancel: {
                showDeleteConfirmation = false
            }
        )
    }
    
    private func deleteSelectedNotes() {
        // 선택된 항목들의 클라이언트 노트를 비우고 동기화
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
                    notes: [] // 모든 노트 삭제
                )
                clientsStore.clients[idx] = updated
                // 채팅 스토어에도 반영하여 다른 화면과 동기화
                ChatStore.shared.setNotes([], for: current.id)
            }
        }
        refreshNotesFromClients()
        selectedNoteIds.removeAll()
        isSelectionMode = false
        showDeleteConfirmation = false
    }
    
    private func movePinnedNote(from sourceIndices: IndexSet, to destination: Int) {
        // 현재 선택된 필터 기준으로 화면에 보이는 정렬 규칙을 동일하게 적용
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
        
        // 핀된 노트들만 추출
        var pinnedNotesInDisplayOrder = currentFilteredNotes.filter { $0.isPinned }
        
        guard let sourceIndex = sourceIndices.first,
              sourceIndex < pinnedNotesInDisplayOrder.count else {
            return
        }
        
        // 드래그된 노트를 새 위치로 이동 (가시 영역 내)
        let draggedNote = pinnedNotesInDisplayOrder.remove(at: sourceIndex)
        let safeDestination = min(destination, pinnedNotesInDisplayOrder.count)
        pinnedNotesInDisplayOrder.insert(draggedNote, at: safeDestination)
        
        // 전역 핀 순서를 보존하면서, 현재 필터에 보이는 항목들의 상대 순서만 교체
        // 1) 전역 핀 목록 (현재 순서) 복원
        var globalPinnedIds: [UUID] = clientsStore.clients
            .filter { $0.pin }
            .sorted {
                let ai = PinOrderManager.shared.getPinIndex(for: $0.id) ?? Int.max
                let bi = PinOrderManager.shared.getPinIndex(for: $1.id) ?? Int.max
                if ai != bi { return ai < bi }
                return $0.id.uuidString < $1.id.uuidString
            }
            .map { $0.id }
        
        // 2) 현재 화면에 보이는 핀 항목들의 기존 위치
        let visiblePinnedIdsNewOrder = pinnedNotesInDisplayOrder.map { $0.id }
        let visiblePositionsInGlobal: [Int] = visiblePinnedIdsNewOrder.compactMap { id in
            globalPinnedIds.firstIndex(of: id)
        }.sorted()
        
        // 3) 보이는 항목들의 새 순서를 전역 목록의 동일한 위치들에 대입
        for (i, pos) in visiblePositionsInGlobal.enumerated() where i < visiblePinnedIdsNewOrder.count {
            globalPinnedIds[pos] = visiblePinnedIdsNewOrder[i]
        }
        
        // 4) 핀 순서 반영
        PinOrderManager.shared.reorderPins(globalPinnedIds)
        
        // 5) 로컬 표시 갱신
        refreshNotesFromClients()
    }
    
    // MARK: - Mapping Helpers
    
    private func refreshNotesFromClients() {
        let clients = clientsStore.clients
        // 핀 인덱스의 최대값을 구해 큰 값이 상단에 오도록 pinOrder 계산
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
    
    private func summarizeContent(for note: Note?) -> String {
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
    
    private var companyNames: [String] {
        Set(clientsStore.clients.compactMap { client in
            let trimmed = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }).sorted()
    }
    
    private var availableFilters: [NotesFilterItem] {
        let all = NotesFilterItem(filter: .all, isEnabled: true)
        let companyFilters = companyNames.map { NotesFilterItem(filter: .company($0), isEnabled: true) }
        return [all] + companyFilters
    }
}

// MARK: - Supporting Types

struct NoteItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let author: String
    let content: String
    let company: String
    let createdAt: Date
    let isPinned: Bool
    var pinOrder: Int // 핀 순서 (클수록 위에 표시)
    
    init(id: UUID = UUID(), author: String, content: String, company: String, createdAt: Date, isPinned: Bool, pinOrder: Int = 0) {
        self.id = id
        self.author = author
        self.content = content
        self.company = company
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.pinOrder = pinOrder
    }
}

// MARK: - Sample Data

var sampleNotes: [NoteItem] = [
    NoteItem(id: UUID(uuidString: "12345678-1234-1234-1234-123456789001")!, author: "Karyn Hakyung Kim", content: "Video [94128942198382]", company: "Apple", createdAt: Date(timeIntervalSince1970: 1700000000), isPinned: true, pinOrder: 2),
    NoteItem(id: UUID(uuidString: "12345678-1234-1234-1234-123456789002")!, author: "Taki", content: "Video [94128942198382]", company: "Apex", createdAt: Date(timeIntervalSince1970: 1699999000), isPinned: true, pinOrder: 1),
    NoteItem(id: UUID(uuidString: "12345678-1234-1234-1234-123456789003")!, author: "Zani", content: "Video [94128942198382]", company: "Google", createdAt: Date(timeIntervalSince1970: 1699998000), isPinned: false, pinOrder: 0),
    NoteItem(id: UUID(uuidString: "12345678-1234-1234-1234-123456789004")!, author: "Gyeong", content: "Video [94128942198382]", company: "Apple", createdAt: Date(timeIntervalSince1970: 1699997000), isPinned: false, pinOrder: 0),
    NoteItem(id: UUID(uuidString: "12345678-1234-1234-1234-123456789005")!, author: "Nathon", content: "Video [94128942198382]", company: "Apex", createdAt: Date(timeIntervalSince1970: 1699996000), isPinned: false, pinOrder: 0),
    NoteItem(id: UUID(uuidString: "12345678-1234-1234-1234-123456789006")!, author: "Daisy", content: "Video [94128942198382]", company: "Google", createdAt: Date(timeIntervalSince1970: 1699995000), isPinned: false, pinOrder: 0)
]

#Preview {
    NavigationStack {
        NotesManagementView()
            .environmentObject(NavigationRouter())
    }
}
