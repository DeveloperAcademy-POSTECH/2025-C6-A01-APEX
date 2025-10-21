//
//  ContentView.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI

struct ContactsView: View {
    @State private var myProfile: Client? = nil
    @State private var favorites: [Client] = sampleClients.filter { $0.favorite }
    @State private var allUngrouped: [Client] = sampleClients

    @State private var isMyProfileExpanded: Bool = true
    @State private var isFavoritesExpanded: Bool = true
    @State private var isAllExpanded: Bool = true

    @State private var showToast: Bool = false
    @State private var toastText: String = "즐겨찾기를 추가했습니다"

    private enum Metrics {
        static let gap: CGFloat = 8
        // ContactsTopBar와 동일 수치
        static let barContentHeight: CGFloat = 44
        static let barHorizontalPadding: CGFloat = 16
        static let barVerticalPadding: CGFloat = 8
        static let plusButtonSize: CGFloat = 44
        static let plusIconSize: CGFloat = 20
    }

    var body: some View {
        NavigationStack {
            List {
                myProfileSection()

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

                ContactsListSection(
                    title: "All",
                    count: allUngrouped.count,
                    isExpanded: $isAllExpanded,
                    clients: allUngrouped,
                    groupHeaderTitle: "Ungrouped",
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
            .toolbar {
                // principal에 가로 폭을 '강제'로 꽉 채워 좌/우 끝으로 보내기
                ToolbarItem(placement: .principal) {
                    ZStack { // 네비바가 중앙 정렬하려는 성향을 상쇄하기 위한 래퍼
                        HStack(spacing: 0) {
                            // 타이틀 (좌측 정렬, 가변 폭)
                            Text("Contacts")
                                .font(.title1)
                                .foregroundColor(Color("Dark"))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // 우측 + 버튼 (고정 폭/높이로 오른쪽 끝에 고정)
                            PlusToolbarButton(
                                size: Metrics.plusButtonSize,
                                iconSize: Metrics.plusIconSize,
                                normalColor: Color("Primary"),
                                pressedColor: Color("PrimaryHover"),
                                action: onPlusTap
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
                    .frame(maxWidth: .infinity) // principal 컨테이너 자체도 가로 전체 사용
                    .background(Color("Background"))
                }
            }
        }
        .background(Color("Background"))
        .apexToast(
            isPresented: $showToast,
            image: Image(systemName: "star"),
            text: toastText,
            buttonTitle: "되돌리기",
            duration: 1.6
        ) { }
    }

    // MARK: - Sections

    @ViewBuilder
    private func myProfileSection() -> some View {
        Group {
            if let profile = myProfile {
                ContactsSectionHeader(
                    title: "My Profile",
                    count: 0,
                    isExpanded: $isMyProfileExpanded
                )
                .applyListRowCleaning()

                gapRow()

                if isMyProfileExpanded {
                    ContactsRow(client: profile)
                        .applyListRowCleaning()
                }
            }
        }
    }

    // MARK: - Actions

    private func onPlusTap() {
        toastText = "새 연락처 추가를 준비 중입니다"
        presentToast()
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

    // MARK: - Small Helpers

    @ViewBuilder
    private func gapRow() -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: Metrics.gap)
            .applyListRowCleaning()
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

// MARK: - Utilities (local only)

private extension View {
    func applyListRowCleaning() -> some View {
        self
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Toolbar Plus Button (ContactsTopBar의 PlusButton 동일 외형/동작)

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
