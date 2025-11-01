//
//  NotesView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesView: View {
    @State private var selectedFilter: NotesFilter = .all
    @ObservedObject private var clientsStore = ClientsStore.shared
    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var clientToDelete: Client?
    @State private var path: [UUID] = []
    @State private var chatRefreshToken: Int = 0
    
    // 커스텀 삭제 모달 상태
    @State private var showDeleteDialog: Bool = false
    @State private var isDeleteConfirmed: Bool = false
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                mainContent
                
                if showDeleteDialog {
                    OverlayLayer(
                        isVisible: $showDeleteDialog,
                        isChecked: $isDeleteConfirmed,
                        clientToDelete: $clientToDelete,
                        onConfirmDelete: { client in
                            deleteClient(client)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.98).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .zIndex(10)
                    .compositingGroup() // 레이어 합성 안정화
                }
            }
            .apexToast(
                isPresented: $showToast,
                image: Image(systemName: "pin"),
                text: toastText,
                buttonTitle: "되돌리기",
                duration: 1.6
            ) { }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                if let client = clientsStore.clients.first(where: { $0.id == id }) {
                    ChattingView(clientId: id, chatTitle: "\(client.name) \(client.surname)", initialNotes: client.notes)
                        .toolbar(.hidden, for: .navigationBar)
                        .toolbar(.hidden, for: .tabBar)
                } else {
                    ChattingView(clientId: id, chatTitle: "채팅", initialNotes: [])
                        .toolbar(.hidden, for: .navigationBar)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .apexChatNotesUpdated)) { _ in
                chatRefreshToken &+= 1
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            NotesNavigationBar { print("Notes menu tapped") }
            
            NotesFilterTabs(
                selectedFilter: $selectedFilter,
                availableFilters: availableFilters
            )
            
            NotesListView(
                clients: clientsStore.clients,
                selectedFilter: $selectedFilter,
                onTogglePin: { togglePin($0) },
                onDelete: { client in
                    clientToDelete = client
                    isDeleteConfirmed = false
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) {
                        showDeleteDialog = true
                    }
                },
                // 2) row 탭 시 id만 push
                onTapRow: { client in
                    path.append(client.id)
                }
            )
            .id(chatRefreshToken)
            .padding(.vertical, 24)
        }
        .background(Color("Background"))
    }
    
    // MARK: - Filters
    
    private var companyNamesWithNotes: [String] {
        Set(
            clientsStore.clients
                .map { $0.company.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        .sorted()
    }
    
    private var availableFilters: [NotesFilterItem] {
        let allFilter = NotesFilterItem(filter: .all, isEnabled: true)
        let companyFilters = companyNamesWithNotes.map { NotesFilterItem(filter: .company($0), isEnabled: true) }
        return [allFilter] + companyFilters
    }
    
    // MARK: - Actions
    
    private func togglePin(_ client: Client) {
        guard let index = clientsStore.clients.firstIndex(where: { $0.id == client.id }) else { return }
        clientsStore.clients[index] = Client(
            id: client.id,
            profile: client.profile,
            nameCardFront: client.nameCardFront,
            nameCardBack: client.nameCardBack,
            surname: client.surname,
            name: client.name,
            position: client.position,
            company: client.company,
            email: client.email,
            phoneNumber: client.phoneNumber,
            linkedinURL: client.linkedinURL,
            memo: client.memo,
            action: client.action,
            favorite: client.favorite,
            pin: !client.pin,
            notes: client.notes
        )
        toastText = client.pin ? "핀을 해제했습니다" : "핀을 추가했습니다"
        presentToast()
    }
    
    private func deleteClient(_ client: Client) {
        if let index = clientsStore.clients.firstIndex(where: { $0.id == client.id }) {
            clientsStore.clients.remove(at: index)
        }
        if case .company(let name) = selectedFilter,
           !companyNamesWithNotes.contains(name) {
            selectedFilter = .all
        }
        clientToDelete = nil
        isDeleteConfirmed = false
    }
    
    private func presentToast() {
        if showToast {
            showToast = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                showToast = true
            }
        } else {
            showToast = true
        }
    }
}

// MARK: - Overlay Layer (dimmed bg + card)

private struct OverlayLayer: View {
    @Binding var isVisible: Bool
    @Binding var isChecked: Bool
    @Binding var clientToDelete: Client?
    var onConfirmDelete: (Client) -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background (탭 시 닫기)
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisible = false
                        clientToDelete = nil
                        isChecked = false
                    }
                }
            
            // Card
            DeleteConfirmCard(
                isChecked: $isChecked,
                onCancel: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisible = false
                        clientToDelete = nil
                        isChecked = false
                    }
                },
                onDelete: {
                    guard isChecked, let target = clientToDelete else { return }
                    onConfirmDelete(target)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisible = false
                    }
                }
            )
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .zIndex(1)
            .accessibilityAddTraits(.isModal)
        }
    }
}

// MARK: - DeleteConfirmCard

private struct DeleteConfirmCard: View {
    @Binding var isChecked: Bool
    var onCancel: () -> Void
    var onDelete: () -> Void
    
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
        
        // Button spec
        static let buttonHeight: CGFloat = 48
        static let buttonWidth: CGFloat = 133
        static let buttonCorner: CGFloat = 100
        static let buttonHPadding: CGFloat = 16
        static let buttonVPadding: CGFloat = 13
        
        // Confirm section spacing
        static let confirmCheckSpacing: CGFloat = 16
    }
    
    // 색상 스펙
    private let deleteActiveRed = Color(red: 0xCC/255.0, green: 0x41/255.0, blue: 0x41/255.0) // #CC4141
    private let deleteActiveBackground = Color(red: 1.0, green: 0xF6/255.0, blue: 0xF5/255.0) // #FFF6F5
    private let disabledGrayText = Color(red: 0.55, green: 0.55, blue: 0.55) // 기존 gray
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
    
    // MARK: Sections
    
    private var titleSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Metrics.titleTop)
            Text("해당 연락처 노트를\n영구적으로 삭제하겠습니까?")
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
            // 상태 토글은 버튼 액션에서만 애니메이션 처리
            isChecked.toggle()
            print(isChecked)
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
        .accessibilityLabel("내용 확인 동의")
        .accessibilityValue(isChecked ? "선택됨" : "선택 안됨")
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
    
    // MARK: Components
    private var checkboxView: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
            
            Image(systemName: "checkmark")
                .frame(width: 24, height: 24)
                .opacity(isChecked ? 1 : 0)
        }
        //        ZStack {
        //            Circle()
        //                .fill(Color.white)
        //                .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)
        //                .overlay(
        //                    Circle()
        //                        .stroke(checkboxStroke, lineWidth: 1)
        //                )
        //
        //            if isChecked {
        //                Image(systemName: "checkmark")
        //                    .frame(width: 14, height: 14)
        //            }
//        //        }
//            .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)
//            .contentShape(Rectangle())
        // 내부 .animation은 제거하여 중복 트랜잭션 방지
        
    }
    
    private var cancelButton: some View {
        Button(action: onCancel) {
            HStack(alignment: .center, spacing: 10) {
                Text("취소")
                    .font(Font.custom("SF Pro", size: 17).weight(.medium))
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
        Button(action: { if isChecked { onDelete() } }) {
            HStack(alignment: .center, spacing: 10) {
                Text("삭제")
                    .font(Font.custom("SF Pro", size: 17).weight(.medium))
                    .foregroundColor(isChecked ? deleteActiveRed : disabledGrayText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, Metrics.buttonHPadding)
            .padding(.vertical, Metrics.buttonVPadding)
            .frame(width: Metrics.buttonWidth, height: Metrics.buttonHeight, alignment: .center)
            .background(isChecked ? Color.red : Color.gray )
            .cornerRadius(Metrics.buttonCorner)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isChecked)
        .accessibilityHint("확인 후 활성화됩니다.")
    }
}

#Preview {
    NotesView()
}
