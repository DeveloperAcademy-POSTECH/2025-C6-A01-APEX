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
    @Binding var notes: [NoteItem]
    let onDeleteTap: () -> Void
    let onMovePinnedNote: (IndexSet, Int) -> Void
    
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
        List {
            ForEach(filteredNotes, id: \.id) { note in
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
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .moveDisabled(!note.isPinned) // 핀된 노트만 드래그 가능 (드래그 핸들 있음)
            }
            .onMove { sourceIndices, destination in
                print("🔄 onMove 호출됨: sourceIndices=\(sourceIndices), destination=\(destination)")
                let filteredNotesArray = filteredNotes
                let pinnedCount = filteredNotesArray.filter { $0.isPinned }.count
                
                // 핀된 노트들 범위 내에서만 이동 허용
                if sourceIndices.allSatisfy({ $0 < pinnedCount }) && destination <= pinnedCount {
                    print("🔄 이동 허용됨 - 핀된 노트 범위 내")
                    onMovePinnedNote(sourceIndices, destination)
                } else {
                    print("🔄 이동 거부됨 - 핀된 노트 범위를 벗어남")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }
    
    private var filteredNotes: [NoteItem] {
        let baseNotes: [NoteItem]
        
        switch selectedTab {
        case .all:
            baseNotes = notes
        case .apple:
            baseNotes = notes.filter { $0.company == "Apple" }
        case .apex:
            baseNotes = notes.filter { $0.company == "Apex" }
        case .google:
            baseNotes = notes.filter { $0.company == "Google" }
        }
        
        // pinOrder 기반 정렬
        return baseNotes.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned // 핀된 노트 우선
            }
            if lhs.isPinned && rhs.isPinned {
                return lhs.pinOrder > rhs.pinOrder // 핀된 노트는 pinOrder 큰 순 (6,5,4,3,2,1)
            }
            return lhs.createdAt > rhs.createdAt // 일반 노트는 최신순
        }
    }
    
    private var deleteButton: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                onDeleteTap()
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(selectedNoteIds.count)")
                    .font(.body1)
                    .foregroundColor(Color("Error"))
                
                Text("삭제하기")
                    .font(.body2)
                    .foregroundColor(Color("Error"))
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(DeleteButtonStyle())
        .padding(.horizontal, Metrics.horizontalPadding)
        .padding(.bottom, 16)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedNoteIds.count)
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
        static let rowHeight: CGFloat = 72
        static let checkboxSize: CGFloat = 32
        static let profileSize: CGFloat = 48
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 선택 체크박스 - 32px × 32px
            Button(action: onToggleSelection) {
                Circle()
                    .strokeBorder(
                        isSelected ? Color("Primary") : Color("BackgroundDisabled"), 
                        lineWidth: 2
                    )
                    .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)
                    .background(
                        Circle()
                            .fill(isSelected ? Color("Primary") : Color.clear)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .buttonStyle(.plain)
            
            // 프로필 이미지 - 48px × 48px
            Profile(
                image: nil,
                initials: Profile.makeInitials(name: note.author, surname: ""),
                size: .extraSmall,
                fontSize: 30.72,
                backgroundColor: Color("PrimaryContainer"),
                textColor: .white,
                fontWeight: .semibold
            )
            
            // 노트 정보
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(note.author)
                        .font(.body2)
                        .foregroundColor(Color("BlackLabel"))
                    
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color("Primary"))
                    }
                    
                    Spacer()
                }
                
                Text(note.content)
                    .font(.body6)
                    .foregroundColor(Color("GrayLabel"))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .frame(height: Metrics.rowHeight)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapRow)
    }
}

// MARK: - DeleteButtonStyle

struct DeleteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color("ErrorHover") : Color("ErrorContainer"))
            )
    }
}

#Preview {
    @Previewable @State var selectedTab: NoteTab = .all
    @Previewable @State var selectedNoteIds: Set<UUID> = []
    @Previewable @State var isSelectionMode: Bool = false
    @Previewable @State var notes: [NoteItem] = sampleNotes
    
    return NotesManagementListSection(
        selectedTab: $selectedTab,
        selectedNoteIds: $selectedNoteIds,
        isSelectionMode: $isSelectionMode,
        notes: $notes,
        onDeleteTap: { print("Delete tapped") },
        onMovePinnedNote: { _, _ in print("Move tapped") }
    )
}
