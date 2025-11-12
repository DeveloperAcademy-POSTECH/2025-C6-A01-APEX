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
    
    // 샘플 노트 데이터
    @State private var notes: [NoteItem] = sampleNotes
    @State private var pinnedNotes: [NoteItem] = sampleNotes.filter { $0.isPinned }
    
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
        VStack(spacing: 0) {
            NotesManagementListSection(
                selectedTab: $selectedTab,
                selectedNoteIds: $selectedNoteIds,
                isSelectionMode: $isSelectionMode,
                notes: notes,
                onDeleteTap: {
                    showDeleteConfirmation = true
                }
            )
        }
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
        pinnedNotes.removeAll { selectedNoteIds.contains($0.id) }
        selectedNoteIds.removeAll()
        isSelectionMode = false
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

struct NoteItem: Identifiable {
    let id = UUID()
    let author: String
    let content: String
    let company: String
    let createdAt: Date
    let isPinned: Bool
}

// MARK: - Sample Data

let sampleNotes: [NoteItem] = [
    NoteItem(author: "Karyn Hakyung Kim", content: "Video [94128942198382]", company: "Apple", createdAt: Date().addingTimeInterval(-3600), isPinned: true),
    NoteItem(author: "Taki", content: "Video [94128942198382]", company: "Apex", createdAt: Date().addingTimeInterval(-7200), isPinned: true),
    NoteItem(author: "Zani", content: "Video [94128942198382]", company: "Google", createdAt: Date().addingTimeInterval(-10800), isPinned: false),
    NoteItem(author: "Gyeong", content: "Video [94128942198382]", company: "Apple", createdAt: Date().addingTimeInterval(-14400), isPinned: false),
    NoteItem(author: "Nathon", content: "Video [94128942198382]", company: "Apex", createdAt: Date().addingTimeInterval(-18000), isPinned: false),
    NoteItem(author: "Daisy", content: "Video [94128942198382]", company: "Google", createdAt: Date().addingTimeInterval(-21600), isPinned: false)
]

#Preview {
    NavigationStack {
        NotesManagementView()
            .environmentObject(NavigationRouter())
    }
}
