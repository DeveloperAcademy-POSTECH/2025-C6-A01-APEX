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
    
    private enum Metrics {
        static let horizontalPadding: CGFloat = 16
        static let gap: CGFloat = 8
    }
    
    var body: some View {
        ZStack {
            mainContent
            
            if showDeleteConfirmation {
                deleteConfirmationOverlay
            }
        }
        .background(Color("Background"))
        .safeAreaInset(edge: .top) {
            customNavigationBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // 탭 선택
            tabSelector
            
            // 노트 리스트
            notesList
            
            // 하단 삭제 버튼
            if isSelectionMode && !selectedNoteIds.isEmpty {
                deleteButton
            }
        }
    }
    
    private var customNavigationBar: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                Button(action: { router.pop() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()

                Spacer(minLength: 0)

                Button {
                    if isSelectionMode {
                        selectedNoteIds.removeAll()
                        isSelectionMode = false
                    } else {
                        router.pop()
                    }
                } label: {
                    Text("완료")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()
            }
            .frame(height: 44)
            .padding(.horizontal, 12)
            .background(Color("Background"))

            // Centered title
            Text("노트 관리")
                .font(.title5)
                .foregroundColor(.black)
                .lineLimit(1)
                .frame(height: 44)
                .padding(.horizontal, 12)
                .allowsHitTesting(false)
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(NoteTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.body2)
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Metrics.horizontalPadding)
    }
    
    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredNotes) { note in
                    NoteRowView(
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
                showDeleteConfirmation = true
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
    
    // MARK: - Delete Confirmation Components
    
    private var deleteConfirmationOverlay: some View {
        DeleteConfirmationOverlay(
            isVisible: $showDeleteConfirmation,
            selectedCount: selectedNoteIds.count,
            onConfirm: deleteSelectedNotes,
            onCancel: {
                showDeleteConfirmation = false
            }
        )
    }
    
    private func toggleSelection(for noteId: UUID) {
        if selectedNoteIds.contains(noteId) {
            selectedNoteIds.remove(noteId)
        } else {
            selectedNoteIds.insert(noteId)
        }
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
    NoteItem(author: "Taki", content: "Video [94128942198382]", company: "Apex", createdAt: Date().addingTimeInterval(-7200), isPinned: false),
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

// MARK: - Note Row View

private struct NoteRowView: View {
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
            
            // 프로필 이미지
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: Metrics.profileSize, height: Metrics.profileSize)
                .overlay(
                    Text(note.author.prefix(1))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.gray)
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

// MARK: - Delete Confirmation Overlay

private struct DeleteConfirmationOverlay: View {
    @Binding var isVisible: Bool
    @State private var isChecked: Bool = false
    let selectedCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // 딤 배경
            Color.black.opacity(0.35)
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    onCancel()
                    isChecked = false
                }
            
            // 삭제 확인 카드
            DeleteConfirmationCard(
                selectedCount: selectedCount,
                isChecked: $isChecked,
                onCancel: {
                    onCancel()
                    isChecked = false
                },
                onConfirm: {
                    guard isChecked else { return }
                    onConfirm()
                    isVisible = false
                    isChecked = false
                }
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Delete Confirmation Card

private struct DeleteConfirmationCard: View {
    let selectedCount: Int
    @Binding var isChecked: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void
    
    private enum Metrics {
        static let corner: CGFloat = 34
        static let paddingH: CGFloat = 14
        static let paddingV: CGFloat = 14
        
        static let titleTop: CGFloat = 8
        static let titleToBody: CGFloat = 10
        static let bodyToCheck: CGFloat = 10
        static let checkToButtons: CGFloat = 24
        
        static let buttonsSpacing: CGFloat = 16
        static let checkboxSize: CGFloat = 24
        
        static let buttonHeight: CGFloat = 48
        static let buttonWidth: CGFloat = 133
        static let buttonCorner: CGFloat = 100
        static let buttonHPadding: CGFloat = 16
        static let buttonVPadding: CGFloat = 13
        
        static let confirmCheckSpacing: CGFloat = 16
    }
    
    private let deleteActiveRed = Color(red: 0xCC/255.0, green: 0x41/255.0, blue: 0x41/255.0)
    private let deleteActiveBackground = Color(red: 1.0, green: 0xF6/255.0, blue: 0xF5/255.0)
    private let disabledGrayText = Color(red: 0.55, green: 0.55, blue: 0.55)
    private let checkboxStroke = Color("BackgroundDisabled")
    
    var body: some View {
        VStack(spacing: 0) {
            titleSection
            bodySection
            confirmCheckSection
            buttonsSection
        }
        .padding(.top, Metrics.paddingV)
        .background(
            ZStack {
                Color.clear.background(.ultraThinMaterial)
                Color(.sRGB, red: 245/255, green: 245/255, blue: 245/255, opacity: 0.4)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        )
        .frame(maxWidth: 309)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }
    
    private var titleSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Metrics.titleTop)
            Text("\(selectedCount)개의 연락처 노트를\n영구적으로 삭제하겠습니까?")
                .font(.body1)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Metrics.paddingH)
            Spacer().frame(height: Metrics.titleToBody)
        }
    }
    
    private var bodySection: some View {
        Text("연락처 내 모든 노트와 파일이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
            .font(.body3)
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Metrics.paddingH + 8)
            .padding(.bottom, Metrics.bodyToCheck)
    }
    
    private var confirmCheckSection: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isChecked.toggle()
            }
        } label: {
            HStack(spacing: Metrics.confirmCheckSpacing) {
                checkboxView
                Text("위 내용을 모두 확인했습니다.")
                    .font(.body2)
                    .foregroundColor(.black)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Metrics.paddingH + 8)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    private var buttonsSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Metrics.checkToButtons)
            HStack(spacing: Metrics.buttonsSpacing) {
                cancelButton
                deleteButton
            }
            .padding(.horizontal, Metrics.paddingH)
            .padding(.bottom, Metrics.paddingV)
        }
    }
    
    private var checkboxView: some View {
        ZStack {
            Circle()
                .fill(isChecked ? Color("Primary") : Color.white)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isChecked ? Color("Primary") : checkboxStroke, lineWidth: 1)
                )
            
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .opacity(isChecked ? 1 : 0)
        }
        .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)
        .contentShape(Circle())
        .animation(.easeInOut(duration: 0.2), value: isChecked)
    }
    
    private var cancelButton: some View {
        Button(action: onCancel) {
            HStack(alignment: .center, spacing: 10) {
                Text("취소")
                    .font(.title5)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, Metrics.buttonHPadding)
            .padding(.vertical, Metrics.buttonVPadding)
            .frame(width: Metrics.buttonWidth, height: Metrics.buttonHeight, alignment: .center)
            .background(Color("BackgroundSecondary"))
            .cornerRadius(Metrics.buttonCorner)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var deleteButton: some View {
        Button(action: { if isChecked { onConfirm() } }) {
            HStack(alignment: .center, spacing: 10) {
                Text("삭제")
                    .font(.title5)
                    .foregroundColor(isChecked ? deleteActiveRed : disabledGrayText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, Metrics.buttonHPadding)
            .padding(.vertical, Metrics.buttonVPadding)
            .frame(width: Metrics.buttonWidth, height: Metrics.buttonHeight, alignment: .center)
            .background(isChecked ? deleteActiveBackground : Color("BackgroundSecondary"))
            .cornerRadius(Metrics.buttonCorner)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isChecked)
    }
}
