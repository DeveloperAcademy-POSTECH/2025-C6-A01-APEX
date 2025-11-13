//
//  NotesManagementView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesManagementView: View {
    @EnvironmentObject private var router: NavigationRouter
    @State private var selectedNoteIds: Set<UUID> = []
    @State private var isSelectionMode: Bool = false
    @State private var selectedTab: NoteTab = .all
    @State private var showDeleteConfirmation = false
    @State private var notes: [NoteItem] = sampleNotes
    
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
    }
    
    private var mainContent: some View {
        NotesManagementListSection(
            selectedTab: $selectedTab,
            selectedNoteIds: $selectedNoteIds,
            isSelectionMode: $isSelectionMode,
            notes: $notes,
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
        notes.removeAll { selectedNoteIds.contains($0.id) }
        selectedNoteIds.removeAll()
        isSelectionMode = false
        showDeleteConfirmation = false
    }
    
    private func movePinnedNote(from sourceIndices: IndexSet, to destination: Int) {
        // 현재 표시되는 노트 순서대로 정렬
        let currentFilteredNotes = notes.sorted { lhs, rhs in
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
        
//        // 드래그된 노트를 새 위치로 이동
        let draggedNote = pinnedNotesInDisplayOrder.remove(at: sourceIndex)
        let safeDestination = min(destination, pinnedNotesInDisplayOrder.count)
        pinnedNotesInDisplayOrder.insert(draggedNote, at: safeDestination)
        
        // pinOrder 재할당
        for (index, note) in pinnedNotesInDisplayOrder.enumerated() {
            let newPinOrder = pinnedNotesInDisplayOrder.count - index
            
            if let originalIndex = notes.firstIndex(where: { $0.id == note.id }) {
                notes[originalIndex].pinOrder = newPinOrder
            }
        }
    }
}

// MARK: - Supporting Types

enum NoteTab: String, CaseIterable {
    case all = "All"
    case apple = "Apple"
    case apex = "Apex"
    case google = "Google"
    
    var title: String {
        rawValue
    }
}

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
