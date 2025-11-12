//
//  NotesManagementListSection.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesManagementListSection: View {
    @Binding var selectedTab: NoteTab
    @Binding var selectedNoteIds: Set<UUID>
    @Binding var isSelectionMode: Bool
    let notes: [NoteItem]
    let onDeleteTap: () -> Void
    
    private enum Metrics {
        static let horizontalPadding: CGFloat = 16
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 탭 선택
            NotesManagementTabSelector(selectedTab: $selectedTab)
            
            // 노트 리스트
            notesList
            
            // 하단 삭제 버튼
            if isSelectionMode && !selectedNoteIds.isEmpty {
                deleteButton
            }
        }
    }
    
    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredNotes) { note in
                    NotesManagementRowView(
                        note: note,
                        isSelected: selectedNoteIds.contains(note.id),
                        isSelectionMode: isSelectionMode,
                        onToggleSelection: { toggleSelection(for: note.id) },
                        onTapRow: {
                            if !isSelectionMode {
                                isSelectionMode = true
                            }
                            toggleSelection(for: note.id)
                        }
                    )
                }
            }
        }
    }
    
    private var filteredNotes: [NoteItem] {
        switch selectedTab {
        case .all:
            return notes.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned // 즐겨찾기 우선
                }
                return lhs.createdAt > rhs.createdAt // 최신순
            }
        case .apple:
            return notes.filter { $0.company == "Apple" }
        case .apex:
            return notes.filter { $0.company == "Apex" }
        case .google:
            return notes.filter { $0.company == "Google" }
        }
    }
    
    private var deleteButton: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                onDeleteTap()
            }
        } label: {
            Text("\(selectedNoteIds.count) 삭제하기")
                .font(.body2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red)
                .cornerRadius(8)
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .padding(.bottom, 16)
    }
    
    private func toggleSelection(for noteId: UUID) {
        if selectedNoteIds.contains(noteId) {
            selectedNoteIds.remove(noteId)
        } else {
            selectedNoteIds.insert(noteId)
        }
    }
}

// MARK: - NotesManagementRowView

struct NotesManagementRowView: View {
    let note: NoteItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let onToggleSelection: () -> Void
    let onTapRow: () -> Void
    
    private enum Metrics {
        static let horizontalPadding: CGFloat = 16
        static let rowHeight: CGFloat = 72
        static let checkboxSize: CGFloat = 24
        static let profileSize: CGFloat = 48
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 선택 체크박스
            Button(action: onToggleSelection) {
                Circle()
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.5), lineWidth: 1)
                    .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)
                    .overlay(
                        Circle()
                            .fill(isSelected ? Color.blue : Color.clear)
                            .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .opacity(isSelected ? 1 : 0)
                            )
                    )
            }
            .buttonStyle(.plain)
            
            // 프로필 이미지 - ContactsView와 동일한 디자인
            Profile(
                image: nil,
                initials: Profile.makeInitials(name: note.author, surname: ""),
                size: .small,
                fontSize: 30.72,
                backgroundColor: Color("PrimaryContainer"),
                textColor: .white,
                fontWeight: .semibold
            )
            
            // 노트 정보
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(note.author)
                        .font(.body2)
                        .foregroundColor(.primary)
                    
                    if note.isPinned {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                
                Text(note.content)
                    .font(.body6)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 드래그 핸들 (즐겨찾기만)
            if note.isPinned {
                Button {
                    // 드래그 or 순서 변경 액션
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .frame(height: Metrics.rowHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapRow)
    }
}

#Preview {
    @State var selectedTab: NoteTab = .all
    @State var selectedNoteIds: Set<UUID> = []
    @State var isSelectionMode: Bool = false
    
    return NotesManagementListSection(
        selectedTab: $selectedTab,
        selectedNoteIds: $selectedNoteIds,
        isSelectionMode: $isSelectionMode,
        notes: sampleNotes,
        onDeleteTap: { print("Delete tapped") }
    )
}