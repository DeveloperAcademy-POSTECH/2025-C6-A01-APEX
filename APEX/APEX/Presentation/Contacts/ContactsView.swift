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

    // 내 프로필 상세로 네비게이션 제어
    @State private var showMyProfileView: Bool = false
    @State private var myProfileDummy: DummyClient = sampleMyProfileClient

    private enum Metrics {
        static let gap: CGFloat = 8
        static let myProfileRowHeight: CGFloat = 72
    }

    // 즐겨찾기 액션 타입
    private enum FavoriteAction {
        case added
        case removed
    }

    var body: some View {
        NavigationStack {
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
                        onDelete: { deleteClient($0) },
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
                    onDelete: { deleteClient($0) },
                    showsSeparatorBelowHeader: false
                )
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .environment(\.defaultMinListRowHeight, 1)
            .scrollContentBackground(.hidden)
            .background(Color("Background"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color("Background"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(
                NavigationLink(
                    "",
                    isActive: $showMyProfileView
                ) {
                    MyProfileView(client: $myProfileDummy)
                }
                .hidden()
            )
        }
        .background(Color("Background"))
        .safeAreaInset(edge: .top) {
            if !showMyProfileView {
                ContactsTopBarReplica(
                    title: "Contacts",
                    onPlus: onPlusTap
                )
                .background(Color("Background"))
            }
        }
        .sheet(isPresented: $isProfileAddPresented) {
            ProfileAddView(onComplete: { newClient in
                allUngrouped.insert(newClient, at: 0)
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
            duration: 1.6
        ) {
            undoFavoriteAction()
        }
    }

    // MARK: - Actions

    private func onPlusTap() {
        isProfileAddPresented = true
    }

    private func toggleFavorite(_ client: Client) {
        // 되돌리기를 위해 현재 상태 저장
        lastToggledClient = client
        
        if let idx = favorites.firstIndex(where: { $0.id == client.id }) {
            // 즐겨찾기 제거
            favorites.remove(at: idx)
            lastFavoriteAction = .removed
            toastText = "즐겨찾기를 해제했습니다"
        } else {
            // 즐겨찾기 추가
            favorites.append(client)
            lastFavoriteAction = .added
            toastText = "즐겨찾기를 추가했습니다"
        }
        presentToast()
    }

    private func deleteClient(_ client: Client) {
        if let idx = allUngrouped.firstIndex(where: { $0.id == client.id }) {
            allUngrouped.remove(at: idx)
        }
        if let fidx = favorites.firstIndex(where: { $0.id == client.id }) {
            favorites.remove(at: fidx)
        }
    }

    private func navigateToMyProfile() {
        showMyProfileView = true
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
