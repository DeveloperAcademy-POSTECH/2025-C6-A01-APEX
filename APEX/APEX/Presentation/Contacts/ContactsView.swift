//
//  ContentView.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI

struct ContactsView: View {
    @ObservedObject private var store = ClientsStore.shared
    @StateObject private var viewModel = ContactsViewModel()

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

    @EnvironmentObject private var router: NavigationRouter
    var body: some View {
        ZStack {
            mainContent
            if viewModel.showDeleteDialog {
                deleteOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $viewModel.isProfileAddPresented) {
            ProfileAddView(onComplete: { newClient in
                ClientsStore.shared.add(newClient, atTop: true)
                viewModel.isProfileAddPresented = false
                DispatchQueue.main.async {
                    navigateToProfileDetail(newClient)
                }
            })
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
            .padding(.top, 10)
        }
        .apexToast(
            isPresented: $viewModel.showToast,
            image: Image(systemName: "star"),
            text: viewModel.toastText,
            buttonTitle: "되돌리기",
            duration: 3.0
        ) {
            viewModel.send(.undoFavorite)
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        List {
            // MARK: - My Profile (TopBar와 0 간격, Favorites와는 8 간격)
            // My Profile Row (DummyClient -> Client 변환해 표시)
            ContactsRow(
                client: viewModel.myProfileClient ?? convertToClient(blankDummy()),
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
                count: viewModel.favorites.count,
                isExpanded: $viewModel.isFavoritesExpanded,
                clients: viewModel.favorites,
                onToggleFavorite: { viewModel.send(.toggleFavorite($0)) },
                onDelete: { viewModel.send(.showDelete($0)) },
                onTapRow: { navigateToProfileDetail($0) },
                showsSeparatorBelowHeader: true
            )

            // MARK: - All / Ungrouped (기존 디자인)
            ContactsListSection(
                title: "All",
                count: viewModel.allUngrouped.count,
                isExpanded: $viewModel.isAllExpanded,
                clients: viewModel.allUngrouped,
                groupHeaderTitle: nil,
                groupByCompany: true,
                onToggleFavorite: { viewModel.send(.toggleFavorite($0)) },
                onDelete: { viewModel.send(.showDelete($0)) },
                onTapRow: { navigateToProfileDetail($0) },
                showsSeparatorBelowHeader: false
            )
        }
        .listStyle(.plain)
        .transaction { txn in
            txn.animation = nil // 재정렬 시 삭제/삽입 애니메이션 억제 → 깜빡임 제거
        }
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 1)
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .safeAreaBar(edge: .top) {
            ContactsTopBar(
                title: "Contacts",
                onPlus: { viewModel.send(.onPlusTap) }
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
            isVisible: $viewModel.showDeleteDialog,
            isChecked: $viewModel.isDeleteConfirmed,
            clientToDelete: $viewModel.clientToDelete,
            onConfirmDelete: { viewModel.send(.deleteConfirmed($0)) }
        )
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
