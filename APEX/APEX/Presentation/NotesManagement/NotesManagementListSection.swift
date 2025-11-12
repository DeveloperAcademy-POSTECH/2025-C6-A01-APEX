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
            .padding(.horizontal, 16) // 리스트 섹션 내부 좌우 패딩 16
            .padding(.vertical, 8)    // 리스트 섹션 내부 상하 패딩 8
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
                size: .small,
                fontSize: nil, // 기본 크기 사용
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
            
            // 햄버거 버튼 (즐겨찾기일 때만 표시)
            if note.isPinned {
                Button {
                    // 드래그 앤 드롭 기능 (현재 미구현)
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("BlackLabel"))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: Metrics.rowHeight)
        .background(Color.clear) // 투명 배경
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
    
    return NotesManagementListSection(
        selectedTab: $selectedTab,
        selectedNoteIds: $selectedNoteIds,
        isSelectionMode: $isSelectionMode,
        notes: sampleNotes,
        onDeleteTap: { print("Delete tapped") }
    )
}
