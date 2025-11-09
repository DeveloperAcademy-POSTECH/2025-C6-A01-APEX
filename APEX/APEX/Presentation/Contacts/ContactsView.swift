//
//  ContentView.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI

struct ContactsView: View {
    @State private var favorites: [Client] = sampleClients.filter { $0.favorite }
    @State private var allUngrouped: [Client] = sampleClients

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
    @State private var myProfileDummy: DummyClient = sampleMyProfileClient
    
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
        .scrollEdgeEffectStyle(.soft, for: .top)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isProfileAddPresented) {
            ProfileAddView(onComplete: { newClient in
                allUngrouped.insert(newClient, at: 0)
                ClientsStore.shared.add(newClient, atTop: true)
                isProfileAddPresented = false
                toastText = "연락처가 추가되었습니다"
                presentToast()
            })
            .padding(.top, 30)
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
        ZStack(alignment: .top) {
            // List를 ZStack의 배경으로 이동
            List {
                // MARK: - My Profile (TopBar와 0 간격, Favorites와는 8 간격)
                // My Profile Row (DummyClient -> Client 변환해 표시)
                ContactsRow(
                    client: convertToClient(myProfileDummy),
                    onToggleFavorite: nil,
                    onDelete: nil,
                    onTap: { navigateToMyProfile() },
                    rowHeight: Metrics.myProfileRowHeight,
                    subtitleOverride: "My Profile"
                )
                .applyListRowCleaning()

                gapRow() // Favorites와 8 간격

                // MARK: - Favorites
                if !favorites.isEmpty {
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
                }

                // MARK: - All / Ungrouped
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
            .safeAreaInset(edge: .top, spacing: 0) {
                // TopBar 높이만큼 투명한 영역 확보
                Color.clear.frame(height: 68)
            }
            
            // TopBar를 ZStack 상단에 오버레이로 배치
            if !showMyProfileView && !showProfileDetailView {
                VStack {
                    ContactsTopBarReplica(
                        title: "Contacts",
                        onPlus: onPlusTap
                    )
                    Spacer()
                }
            }
        }
        // Removed hidden NavigationLinks; Router handles navigation
        .background(Color("Background"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color("Background"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
            if let idx = allUngrouped.firstIndex(where: { $0.id == base.id }) {
                allUngrouped[idx] = updatedClient
            }
            if let fidx = favorites.firstIndex(where: { $0.id == base.id }) {
                favorites[fidx] = updatedClient
            }
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
        
        if let idx = favorites.firstIndex(where: { $0.id == client.id }) {
            // 즐겨찾기 제거 (All 섹션은 건드리지 않음)
            favorites.remove(at: idx)
            lastFavoriteAction = .removed
            toastText = "즐겨찾기를 해제했습니다"
        } else {
            // 즐겨찾기 추가 (All 섹션은 건드리지 않음)
            favorites.append(client)
            lastFavoriteAction = .added
            toastText = "즐겨찾기를 추가했습니다"
        }
        
        // favorites 배열만 변경하므로 All 섹션은 움직이지 않음
        presentToast()
    }

    private func deleteClient(_ client: Client) {
        if let idx = allUngrouped.firstIndex(where: { $0.id == client.id }) {
            allUngrouped.remove(at: idx)
        }
        if let fidx = favorites.firstIndex(where: { $0.id == client.id }) {
            favorites.remove(at: fidx)
        }
        
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
        
        print("🔄 되돌리기 실행: \(client.name) \(client.surname), 액션: \(action)")
        
        switch action {
        case .added:
            // 추가된 것을 되돌리기 (제거)
            if let idx = favorites.firstIndex(where: { $0.id == client.id }) {
                favorites.remove(at: idx)
                print("✅ 즐겨찾기에서 제거됨")
            }
        case .removed:
            // 제거된 것을 되돌리기 (추가)
            if !favorites.contains(where: { $0.id == client.id }) {
                favorites.append(client)
                print("✅ 즐겨찾기에 추가됨")
            }
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

// MARK: - TopBar Replica (툴바 슬롯을 대체하는 안전영역 상단 커스텀 바)

private struct ContactsTopBarReplica: View {
    let title: String
    let onPlus: () -> Void

    private enum Metrics {
        static let barContentHeight: CGFloat = 44
        static let barHorizontalPadding: CGFloat = 16
        static let barVerticalPadding: CGFloat = 8
        static let plusButtonSize: CGFloat = 44
        static let plusIconSize: CGFloat = 20
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Text(title)
                    .font(.title1)
                    .foregroundColor(Color("Dark"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                PlusToolbarButton(
                    size: Metrics.plusButtonSize,
                    iconSize: Metrics.plusIconSize,
                    normalColor: Color("Primary"),
                    pressedColor: Color("PrimaryHover"),
                    action: onPlus
                )
                .frame(width: Metrics.plusButtonSize, height: Metrics.plusButtonSize, alignment: .trailing)
                .accessibilityLabel(Text("추가"))
            }
            .frame(height: Metrics.barContentHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.barHorizontalPadding)
            .padding(.vertical, Metrics.barVerticalPadding)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Toolbar Plus Button

private struct PlusToolbarButton: View {
    let size: CGFloat
    let iconSize: CGFloat
    let normalColor: Color
    let pressedColor: Color
    let action: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)

                Image(systemName: "plus")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(isPressed ? pressedColor : normalColor)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect()
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = false }
                }
        )
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
