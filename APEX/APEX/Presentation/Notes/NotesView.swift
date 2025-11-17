//
//  NotesView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var router: NavigationRouter
    @State private var selectedFilter: NotesFilter = .all
    @ObservedObject private var clientsStore = ClientsStore.shared
    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var clientToDelete: Client?
    
    // 되돌리기 기능을 위한 상태
    @State private var lastToggledClientId: UUID?
    @State private var lastPinAction: PinAction?
    
    // 커스텀 삭제 모달 상태
    @State private var showDeleteDialog: Bool = false
    @State private var isDeleteConfirmed: Bool = false
    
    // 핀 액션 타입
    private enum PinAction {
        case added
        case removed
    }
    
    var body: some View {
        mainContent
            .apexToast(
                isPresented: $showToast,
                image: Image(systemName: "pin"),
                text: toastText,
                buttonTitle: "되돌리기",
                duration: 1.6,
                onButtonTap: undoPinAction
            )
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .top) {
                NotesNavigationBar { print("Notes menu tapped") }
                    .background(Color("Background"))
            }
            .toolbar(.hidden, for: .navigationBar)
            .windowOverlay(isPresented: $showDeleteDialog) {
                deleteOverlay
            }
        .onReceive(NotificationCenter.default.publisher(for: .apexChatNotesUpdated)) { notif in
            guard let clientId = notif.userInfo?["clientId"] as? UUID,
                  let idx = clientsStore.clients.firstIndex(where: { $0.id == clientId }) else { return }

            let old = clientsStore.clients[idx]
            let latestNotes = ChatStore.shared.notes(for: clientId)

            // Replace whole element to trigger @Published update
            clientsStore.clients[idx] = Client(
                id: old.id,
                profile: old.profile,
                nameCardFront: old.nameCardFront,
                nameCardBack: old.nameCardBack,
                surname: old.surname,
                name: old.name,
                position: old.position,
                company: old.company,
                email: old.email,
                phoneNumber: old.phoneNumber,
                linkedinURL: old.linkedinURL,
                memo: old.memo,
                action: old.action,
                favorite: old.favorite,
                pin: old.pin,
                notes: latestNotes
            )
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            NotesFilterTabs(
                selectedFilter: $selectedFilter,
                availableFilters: availableFilters
            )
            
            NotesListView(
                clients: $clientsStore.clients,
                selectedFilter: $selectedFilter,
                onTogglePin: togglePin,
                onDelete: showDeleteConfirmation,
                onTapRow: { router.push(.chat($0.id)) }
            )
        }
        .background(Color("Background"))
    }
    
    private var deleteOverlay: some View {
        OverlayLayer(
            isVisible: $showDeleteDialog,
            isChecked: $isDeleteConfirmed,
            clientToDelete: $clientToDelete,
            onConfirmDelete: deleteClient
        )
    }
    
    // MARK: - Computed Properties
    
    private var companyNamesWithNotes: [String] {
        Set(clientsStore.clients.compactMap { client in
            let trimmed = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }).sorted()

    }
    
    private var availableFilters: [NotesFilterItem] {
        let allFilter = NotesFilterItem(filter: .all, isEnabled: true)
        let companyFilters = companyNamesWithNotes.map { 
            NotesFilterItem(filter: .company($0), isEnabled: true) 
        }
        return [allFilter] + companyFilters
    }
    
    // MARK: - Navigation
    
    @ViewBuilder
    private func chattingDestination(for clientId: UUID) -> some View {
        // TODO: Replace with actual chatting view
        // For now, we'll show a placeholder or you can replace this with your actual chatting view
        Text("Chat for client: \(clientId.uuidString)")
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Actions
    
    private func showDeleteConfirmation(_ client: Client) {
        clientToDelete = client
        showDeleteDialog = true
    }
    
    private func togglePin(_ client: Client) {
        guard let index = clientsStore.clients.firstIndex(where: { $0.id == client.id }) else { return }
        
        // 되돌리기를 위해 현재 상태 저장 (ID만 저장)
        lastToggledClientId = client.id
        lastPinAction = client.pin ? .removed : .added
        
        print("🔧 핀 토글 시작: \(client.autoFormattedName)")
        print("🔧 현재 핀 상태: \(client.pin) → 변경될 상태: \(!client.pin)")
        print("🔧 저장된 클라이언트 ID: \(client.id)")
        print("🔧 저장된 액션: \(lastPinAction!)")
        
        let newPinState = !client.pin
        
        // PinOrderManager 업데이트
        if newPinState {
            PinOrderManager.shared.pinClient(client.id)
        } else {
            PinOrderManager.shared.unpinClient(client.id)
        }
        
        // 핀 상태 토글 (ID 유지)
        clientsStore.clients[index] = Client(
            id: client.id,  // ✅ 기존 ID 유지
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
            pin: newPinState,
            notes: client.notes
        )
        
        // ✅ 수정: 변경될 상태 기준으로 메시지 생성
        toastText = newPinState ? "핀을 추가했습니다" : "핀을 해제했습니다"
        print("🔧 토스트 메시지: \(toastText)")
        presentToast()
    }
    
    private func deleteClient(_ client: Client) {
        // 노트만 모두 삭제 (연락처는 유지)
        ChatStore.shared.setNotes([], for: client.id)
        
        // 회사 필터가 더 이상 노트를 가진 항목이 없다면 전체로 변경
        if case .company(let name) = selectedFilter,
           !companyNamesWithNotes.contains(name) {
            selectedFilter = .all
        }
        
        // 모달 상태 초기화
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
    
    // 핀 되돌리기 기능
    private func undoPinAction() {
        print("🔄🔄🔄 핀 되돌리기 버튼 클릭됨!!!")
        
        print("🔍 저장된 상태 확인:")
        print("  - lastToggledClientId: \(lastToggledClientId?.uuidString ?? "nil")")
        print("  - lastPinAction: \(String(describing: lastPinAction))")
        
        guard let clientId = lastToggledClientId,
              let action = lastPinAction else { 
            print("❌ 되돌릴 수 있는 핀 액션이 없음")
            return 
        }
        
        guard let index = clientsStore.clients.firstIndex(where: { $0.id == clientId }) else {
            print("❌ 클라이언트를 찾을 수 없음: \(clientId)")
            return
        }
        
        let currentClient = clientsStore.clients[index]
        print("🔄 되돌리기 실행: \(currentClient.autoFormattedName)")
        print("🔄 원본 액션: \(action), 현재 핀 상태: \(currentClient.pin)")
        
        // 핀 상태를 원래대로 되돌리기
        let originalPinState: Bool
        switch action {
        case .added:
            originalPinState = false  // 추가된 것을 되돌리기 (false로)
            print("🔄 추가를 되돌림: true → false")
            PinOrderManager.shared.unpinClient(clientId)
        case .removed:
            originalPinState = true   // 제거된 것을 되돌리기 (true로)
            print("🔄 제거를 되돌림: false → true")
            PinOrderManager.shared.pinClient(clientId)
        }
        
        // ✅ 수정: 현재 클라이언트를 기준으로 핀 상태만 변경 (ID 유지)
        clientsStore.clients[index] = Client(
            id: currentClient.id,  // ✅ 기존 ID 유지
            profile: currentClient.profile,
            nameCardFront: currentClient.nameCardFront,
            nameCardBack: currentClient.nameCardBack,
            surname: currentClient.surname,
            name: currentClient.name,
            position: currentClient.position,
            company: currentClient.company,
            email: currentClient.email,
            phoneNumber: currentClient.phoneNumber,
            linkedinURL: currentClient.linkedinURL,
            memo: currentClient.memo,
            action: currentClient.action,
            favorite: currentClient.favorite,
            pin: originalPinState,
            notes: currentClient.notes
        )
        
        print("✅ 핀 상태가 \(originalPinState)로 되돌려짐")
        print("✅ 업데이트된 클라이언트 핀 상태: \(clientsStore.clients[index].pin)")
        
        // 되돌리기 완료 후 상태 초기화
        lastToggledClientId = nil
        lastPinAction = nil
        showToast = false
        print("🔄 핀 되돌리기 완료, 토스트 숨김")
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
            // 전체화면 딤 배경
            Color.black.opacity(0.35)
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    isVisible = false
                    clientToDelete = nil
                    isChecked = false
                }
            
            // 삭제 확인 카드
            DeleteConfirmCard(
                isChecked: $isChecked,
                onCancel: {
                    isVisible = false
                    clientToDelete = nil
                    isChecked = false
                },
                onDelete: {
                    guard isChecked, let target = clientToDelete else { return }
                    onConfirmDelete(target)
                    isVisible = false
                }
            )
            .padding(.horizontal, 24)
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
            withAnimation(.easeInOut(duration: 0.2)) {
                isChecked.toggle()
            }
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
        Button(action: { if isChecked { onDelete() } }) {
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
        .accessibilityHint("확인 후 활성화됩니다.")
    }
}

#Preview {
    NotesView()
}
