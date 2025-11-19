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
    
    // 로컬 상태로 체크박스 관리 (NotesView 방식으로 통일)
    @State private var isDeleteConfirmed: Bool = false
    
    private enum Metrics {
        static let gap: CGFloat = 8
        static let myProfileRowHeight: CGFloat = 72
    }

    @EnvironmentObject private var router: NavigationRouter
    var body: some View {
        mainContent
            .toolbar(.hidden, for: .navigationBar)
            .windowOverlay(isPresented: $viewModel.showDeleteDialog) {
                deleteOverlay
            }
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
        ZStack {
            // 딤 배경
            Color.black.opacity(0.35)
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    isDeleteConfirmed = false
                    viewModel.send(.dismissDelete)
                }
            
            // 삭제 확인 카드 (로컬 상태 사용)
            ContactsDeleteConfirmCard(
                isChecked: $isDeleteConfirmed,
                onCancel: {
                    isDeleteConfirmed = false
                    viewModel.send(.dismissDelete)
                },
                onDelete: {
                    guard isDeleteConfirmed, let target = viewModel.clientToDelete else { return }
                    viewModel.send(.deleteConfirmed(target))
                    isDeleteConfirmed = false
                }
            )
            .padding(.horizontal, 46)
            .contentShape(Rectangle()) // 모달 카드 영역의 터치를 차단
            .onTapGesture { } // 빈 제스처로 터치 이벤트 흡수
        }
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
// MARK: - DeleteConfirmCard

private struct ContactsDeleteConfirmCard: View {
    @Binding var isChecked: Bool
    var onCancel: () -> Void
    var onDelete: () -> Void
    
    private enum Metrics {
        // 통일된 값들
        static let cornerRadius: CGFloat = 32
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
        
        // 간격들
        static let titleTop: CGFloat = 8
        static let sectionSpacing: CGFloat = 16
        static let checkboxToButtonSpacing: CGFloat = 24  // 체크박스와 버튼 사이
        static let buttonSpacing: CGFloat = 16
        
        // 체크박스
        static let checkboxSize: CGFloat = 24
        static let confirmSpacing: CGFloat = 16
        
        // 버튼
        static let buttonHeight: CGFloat = 48
        static let buttonWidth: CGFloat = 120
        static let buttonCorner: CGFloat = 100
    }
    
    // 색상 스펙
    private let deleteActiveRed = Color("Error")
    private let deleteActiveBackground = Color("ErrorHover")
    private let disabledGrayText = Color("GrayLabel")
    private let checkboxStroke = Color("BackgroundDisabled")
    
    var body: some View {
        VStack(spacing: 0) {
            titleSection
            
            Spacer()
                .frame(height: Metrics.sectionSpacing)
            
            bodySection
            
            Spacer()
                .frame(height: Metrics.sectionSpacing)
            
            confirmSection
            
            Spacer()
                .frame(height: Metrics.checkboxToButtonSpacing)
            
            buttonsSection
        }
        .padding(Metrics.horizontalPadding)
        .glassEffect(in: .rect(cornerRadius: Metrics.cornerRadius))
    }
    
    // MARK: - Sections
    
    private var titleSection: some View {
        Text("해당 연락처를\n영구적으로 삭제하겠습니까?")
            .font(.body1)
            .foregroundColor(Color("BlackLabel"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.top, 8)
    }
    
    private var bodySection: some View {
        Text("연락처 및 관련 데이터가 모두 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
            .font(.body3)
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
    
    private var confirmSection: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.1)) {
                isChecked.toggle()
            }
        } label: {
            HStack(spacing: Metrics.confirmSpacing) {
                checkboxView
                Text("위 내용을 모두 확인했습니다.")
                    .font(.body2)
                    .foregroundColor(.black)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8) // 본문과 시작점 맞추기 위해 동일한 패딩
    }
    
    private var buttonsSection: some View {
        HStack(spacing: Metrics.buttonSpacing) {
            cancelButton
            deleteButton
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
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
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
