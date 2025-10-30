//
//  ContentView.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI

struct ContactsView: View {
    @State private var myProfile: Client? = {
        // 실제 사용자 프로필로 교체하세요.
        sampleClients.first
    }()

    @State private var favorites: [Client] = sampleClients.filter { $0.favorite }
    @State private var allUngrouped: [Client] = sampleClients

    @State private var isFavoritesExpanded: Bool = true
    @State private var isAllExpanded: Bool = true

    @State private var showToast: Bool = false
    @State private var toastText: String = "즐겨찾기를 추가했습니다"
    @State private var isProfileAddPresented: Bool = false

    // 내 프로필 상세로 네비게이션 제어
    @State private var showMyProfileView: Bool = false
    @State private var myProfileDummy: DummyClient = sampleMyProfileClient

    private enum Metrics {
        static let gap: CGFloat = 8
        static let myProfileRowHeight: CGFloat = 72
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - My Profile (TopBar와 0 간격, Favorites와는 8 간격)
                if let profile = myProfile {
                    ContactsRow(
                        client: profile,
                        onToggleFavorite: nil,
                        onDelete: nil,
                        onTap: { navigateToMyProfile(profile) },
                        rowHeight: Metrics.myProfileRowHeight,
                        subtitleOverride: "My Profile"
                    )
                    .applyListRowCleaning()

                    gapRow() // Favorites와 8 간격
                }

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
            ContactsTopBarReplica(
                title: "Contacts",
                onPlus: onPlusTap
            )
            .background(Color("Background"))
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
        ) { }
    }

    // MARK: - Actions

    private func onPlusTap() {
        isProfileAddPresented = true
    }

    private func toggleFavorite(_ client: Client) {
        if let idx = favorites.firstIndex(where: { $0.id == client.id }) {
            favorites.remove(at: idx)
            toastText = "즐겨찾기를 해제했습니다"
        } else {
            favorites.append(client)
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

    private func navigateToMyProfile(_ client: Client) {
        myProfileDummy = convertToDummy(client)
        showMyProfileView = true
    }

    private func convertToDummy(_ client: Client) -> DummyClient {
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
