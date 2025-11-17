//
//  ContentView.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI

struct ContactsView: View {
    @ObservedObject private var store = ClientsStore.shared
    private var favorites: [Client] {
        return Array(store.clients.dropFirst()).filter { $0.favorite }
    }
    private var allUngrouped: [Client] {
        return Array(store.clients.dropFirst())
    }

    @State private var isFavoritesExpanded: Bool = true
    @State private var isAllExpanded: Bool = true

    @State private var showToast: Bool = false
    @State private var toastText: String = "즐겨찾기를 추가했습니다"
    @State private var isProfileAddPresented: Bool = false

    // 되돌리기 기능을 위한 상태
    @State private var lastToggledClient: Client?
    @State private var lastFavoriteAction: FavoriteAction?


    // 커스텀 삭제 모달 상태
    @State private var showDeleteDialog: Bool = false
    @State private var isDeleteConfirmed: Bool = false
    @State private var clientToDelete: Client?
    // 내 프로필 상세로 네비게이션 제어
    @State private var showMyProfileView: Bool = false
    
    // 타인 프로필 상세로 네비게이션 제어
    @State private var showProfileDetailView: Bool = false
    @State private var selectedClient: Client?
    @State private var selectedDummy: DummyClient?

    private enum Metrics {
        static let gap: CGFloat = 8
        static let myProfileRowHeight: CGFloat = 72
    }

    // 즐겨찾기 액션 타입
    private enum FavoriteAction {
        case added
        case removed
    }

    @EnvironmentObject private var router: NavigationRouter
    var body: some View {
        ZStack {
            mainContent
            if showDeleteDialog {
                deleteOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isProfileAddPresented) {
            ProfileAddView(onComplete: { newClient in
                ClientsStore.shared.add(newClient, atTop: true)
                isProfileAddPresented = false
                DispatchQueue.main.async {
                    navigateToProfileDetail(newClient)
                }
            })
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
            .padding(.top, 10)
        }
        .apexToast(
            isPresented: $showToast,
            image: Image(systemName: "star"),
            text: toastText,
            buttonTitle: "되돌리기",
            duration: 3.0
        ) {
            undoFavoriteAction()
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        List {
            // MARK: - My Profile (TopBar와 0 간격, Favorites와는 8 간격)
            // My Profile Row (DummyClient -> Client 변환해 표시)
            ContactsRow(
                client: store.clients.first ?? convertToClient(blankDummy()),
                onToggleFavorite: nil,
                onDelete: nil,
                onTap: { navigateToMyProfile() },
                rowHeight: Metrics.myProfileRowHeight,
                subtitleOverride: "My Profile"
            )
            .equatable()
            .applyListRowCleaning()

            gapRow() // Favorites와 8 간격(빈 경우에도 고정 간격 유지)

            // MARK: - Favorites
            ContactsListSection(
                title: "Favorites",
                count: favorites.count,
                isExpanded: $isFavoritesExpanded,
                clients: favorites,
                onToggleFavorite: { toggleFavorite($0) },
                onDelete: { showDeleteConfirmation($0) },
                onTapRow: { navigateToProfileDetail($0) },
                showsSeparatorBelowHeader: true
            )

            // MARK: - All / Ungrouped (기존 디자인)
            ContactsListSection(
                title: "All",
                count: allUngrouped.count,
                isExpanded: $isAllExpanded,
                clients: allUngrouped,
                groupHeaderTitle: nil,
                groupByCompany: true,
                onToggleFavorite: { toggleFavorite($0) },
                onDelete: { showDeleteConfirmation($0) },
                onTapRow: { navigateToProfileDetail($0) },
                showsSeparatorBelowHeader: false
            )
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 1)
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .safeAreaBar(edge: .top) {
            ContactsTopBar(
                title: "Contacts",
                onPlus: onPlusTap
            )
        }
        // Removed duplicate hidden links
        .onChange(of: selectedDummy) { newValue in
            guard let base = selectedClient, let updated = newValue else { return }
            let updatedClient = Client(
                id: base.id,
                profile: updated.profile,
                nameCardFront: updated.nameCardFront,
                nameCardBack: updated.nameCardBack,
                surname: updated.surname,
                name: updated.name,
                position: updated.position,
                company: updated.company,
                email: updated.email,
                phoneNumber: updated.phoneNumber,
                linkedinURL: updated.linkedinURL,
                memo: updated.memo,
                action: base.action,
                favorite: base.favorite,
                pin: base.pin,
                notes: base.notes
            )
            ClientsStore.shared.update(updatedClient)
        }
    }
    
    private var deleteOverlay: some View {
        ContactsOverlayLayer(
            isVisible: $showDeleteDialog,
            isChecked: $isDeleteConfirmed,
            clientToDelete: $clientToDelete,
            onConfirmDelete: deleteClient
        )
    }

    // MARK: - Actions

    private func onPlusTap() {
        isProfileAddPresented = true
    }
    
    private func showDeleteConfirmation(_ client: Client) {
        clientToDelete = client
        showDeleteDialog = true
    }

    private func toggleFavorite(_ client: Client) {
        // 되돌리기를 위해 현재 상태 저장
        lastToggledClient = client
        let toggled = Client(
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
            favorite: !client.favorite,
            pin: client.pin,
            notes: client.notes
        )
        ClientsStore.shared.update(toggled)
        lastFavoriteAction = toggled.favorite ? .added : .removed
        toastText = toggled.favorite ? "즐겨찾기를 추가했습니다" : "즐겨찾기를 해제했습니다"
        // favorites 배열만 변경하므로 All 섹션은 움직이지 않음
        presentToast()
    }

    private func deleteClient(_ client: Client) {
        ClientsStore.shared.remove(client.id)
        
        // 모달 상태 초기화
        clientToDelete = nil
        isDeleteConfirmed = false
    }

    private func navigateToMyProfile() {
        router.push(.myProfile)
    }
    
    private func navigateToProfileDetail(_ client: Client) {
        router.push(.profileDetail(client.id))
    }

    private func convertToClient(_ dummy: DummyClient) -> Client {
        Client(
            profile: dummy.profile,
            nameCardFront: dummy.nameCardFront,
            nameCardBack: dummy.nameCardBack,
            surname: dummy.surname,
            name: dummy.name,
            position: dummy.position,
            company: dummy.company,
            email: dummy.email,
            phoneNumber: dummy.phoneNumber,
            linkedinURL: dummy.linkedinURL,
            memo: dummy.memo,
            action: dummy.action,
            favorite: dummy.favorite,
            pin: dummy.pin,
            notes: []
        )
    }
    
    private func convertToDummyClient(_ client: Client) -> DummyClient {
        DummyClient(
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
            pin: client.pin,
            notes: []
        )
    }
    
    private func blankDummy() -> DummyClient {
        DummyClient(
            profile: nil,
            nameCardFront: nil,
            nameCardBack: nil,
            surname: "",
            name: "",
            position: nil,
            company: "",
            email: nil,
            phoneNumber: nil,
            linkedinURL: nil,
            memo: nil,
            action: nil,
            favorite: false,
            pin: false,
            notes: []
        )
    }

    // MARK: - Small Helpers

    @ViewBuilder
    private func gapRow() -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: Metrics.gap)
            .applyListRowCleaning()
    }

    // 토스트를 재표시하기 위한 헬퍼(표시 중에도 다시 트리거 가능)
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
    
    // 즐겨찾기 되돌리기 기능
    private func undoFavoriteAction() {
        print("🔄 되돌리기 버튼 클릭됨")
        
        guard let client = lastToggledClient,
              let action = lastFavoriteAction else { 
            print("❌ 되돌릴 수 있는 액션이 없음")
            return 
        }
        
        print("🔄 되돌리기 실행: \(client.autoFormattedName), 액션: \(action)")
        
        // 저장소의 현재 값을 기준으로 favorite을 되돌림
        if let current = store.clients.first(where: { $0.id == client.id }) {
            let shouldBeFavorite: Bool = {
                switch action {
                case .added:   return false   // 방금 추가했으니 되돌리면 제거
                case .removed: return true    // 방금 제거했으니 되돌리면 추가
                }
            }()
            let reverted = Client(
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
                favorite: shouldBeFavorite,
                pin: current.pin,
                notes: current.notes
            )
            ClientsStore.shared.update(reverted)
            print(shouldBeFavorite ? "✅ 즐겨찾기에 추가됨(되돌리기)" : "✅ 즐겨찾기에서 제거됨(되돌리기)")
        }
        
        // 되돌리기 완료 후 상태 초기화
        lastToggledClient = nil
        lastFavoriteAction = nil
        showToast = false
        print("🔄 되돌리기 완료, 토스트 숨김")
    }
}

// MARK: - Utilities (local only)

private extension View {
    func applyListRowCleaning() -> some View {
        self
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview { ContactsView() }

// MARK: - Delete Confirmation Components
// MARK: - Overlay Layer (dimmed bg + card)

private struct ContactsOverlayLayer: View {
    @Binding var isVisible: Bool
    @Binding var isChecked: Bool
    @Binding var clientToDelete: Client?
    var onConfirmDelete: (Client) -> Void
    
    var body: some View {
        ZStack {
            // 전체화면 딤 배경 - ignoresSafeArea(.all)로 진짜 전체화면 덮기
            Color.black.opacity(0.35)
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    isVisible = false
                    clientToDelete = nil
                    isChecked = false
                }
            
            // 삭제 확인 카드
            ContactsDeleteConfirmCard(
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

private struct ContactsDeleteConfirmCard: View {
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
            Text("해당 연락처를\n영구적으로 삭제하겠습니까?")
                .font(.body1)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Metrics.paddingH)
            Spacer().frame(height: Metrics.titleToBody)
        }
    }
    
    private var bodySection: some View {
        Text("연락처 정보와 관련된 모든 데이터가 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
            .font(.body3)
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Metrics.paddingH + 8)
            .padding(.bottom, Metrics.bodyToCheck)
    }
    
    private var confirmCheckSection: some View {
        Button {
            isChecked.toggle()
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
