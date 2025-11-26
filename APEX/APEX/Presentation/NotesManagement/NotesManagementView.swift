//
//  NotesManagementView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesManagementView: View {
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = NotesManagementViewModel()
    
    var body: some View {
        mainContent
            .windowOverlay(isPresented: Binding(get: { viewModel.showDeleteConfirmation }, set: { viewModel.showDeleteConfirmation = $0 })) {
                deleteConfirmationOverlay
            }
        .background(Color("Background"))
        .safeAreaInset(edge: .top) {
            NotesManagementNavigationBar(
                isSelectionMode: viewModel.isSelectionMode,
                onClose: { router.pop() },
                onComplete: {
                    if viewModel.isSelectionMode {
                        viewModel.send(.completeTapped)
                    } else {
                        router.pop()
                    }
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.send(.onAppear)
        }
    }
    
    private var mainContent: some View {
        NotesManagementListSection(
            selectedFilter: Binding(get: { viewModel.selectedFilter }, set: { viewModel.selectedFilter = $0 }),
            selectedNoteIds: Binding(get: { viewModel.selectedNoteIds }, set: { viewModel.selectedNoteIds = $0 }),
            isSelectionMode: Binding(get: { viewModel.isSelectionMode }, set: { viewModel.isSelectionMode = $0 }),
            notes: Binding(get: { viewModel.notes }, set: { viewModel.notes = $0 }),
            availableFilters: viewModel.availableFilters,
            onDeleteTap: {
                viewModel.send(.deleteTapped)
            },
            onMovePinnedNote: { source, destination in
                viewModel.send(.movePinned(source, destination))
            }
        )
    }
    
    private var deleteConfirmationOverlay: some View {
        NotesManagementDeleteConfirmationOverlay(
            isVisible: Binding(get: { viewModel.showDeleteConfirmation }, set: { viewModel.showDeleteConfirmation = $0 }),
            selectedCount: viewModel.selectedNoteIds.count,
            onConfirm: { viewModel.send(.confirmDelete) },
            onCancel: {
                viewModel.send(.cancelDelete)
            }
        )
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

#Preview {
    NavigationStack {
        NotesManagementView()
            .environmentObject(NavigationRouter())
    }
}
