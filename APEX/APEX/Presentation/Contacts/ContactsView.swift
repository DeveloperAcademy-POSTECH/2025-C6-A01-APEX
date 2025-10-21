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
    }

    var body: some View {
        VStack(spacing: 0) {
            ContactsTopBar(title: "Contacts") { onPlusTap() }

            List {
                // My Profile 섹션(헤더 → gap 8 → 내용) — ListSection 스타일과 동일
                if let profile = myProfile {
                    ContactsSectionHeader(
                        title: "My Profile",
                        count: 0,
                        isExpanded: $isMyProfileExpanded
                    )
                    .applyListRowCleaning()

                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: Metrics.gap)
                        .applyListRowCleaning()

                    if isMyProfileExpanded {
                        ContactsRow(client: profile)
                            .applyListRowCleaning()
                    }
                }

                // Favorites 섹션
                if !favorites.isEmpty {
                    ContactsListSection(
                        title: "Favorites",
                        count: favorites.count,
                        isExpanded: $isFavoritesExpanded,
                        clients: favorites,
                        onToggleFavorite: { toggleFavorite($0) },
                        onDelete: { deleteClient($0) },
                        showsSeparatorBelowHeader: true // 섹션 끝 구분선(8) 추가
                    )
                }

                // All 섹션
                ContactsListSection(
                    title: "All",
                    count: allUngrouped.count,
                    isExpanded: $isAllExpanded,
                    clients: allUngrouped,
                    groupHeaderTitle: "Ungrouped",
                    onToggleFavorite: { toggleFavorite($0) },
                    onDelete: { deleteClient($0) },
                    showsSeparatorBelowHeader: false // 구분선 없음
                )
            }
            .listStyle(.plain)
            .listRowSpacing(0) // 시스템 기본 행 간격 제거
            .environment(\.defaultMinListRowHeight, 1) // 최소 행 높이 낮춰 간격 통제
            .scrollContentBackground(.hidden)
            .background(Color("Background"))
        }
        .apexToast(
            isPresented: $showToast,
            image: Image(systemName: "star"),
            text: toastText,
            buttonTitle: "되돌리기",
            duration: 1.6
        ) { }
    }

    private func onPlusTap() {
        toastText = "새 연락처 추가를 준비 중입니다"
        showToast = true
    }

    private func toggleFavorite(_ client: Client) {
        if let idx = favorites.firstIndex(where: { $0.id == client.id }) {
            // 이미 즐겨찾기 → 해제
            favorites.remove(at: idx)
            toastText = "즐겨찾기를 해제했습니다"
        } else {
            // 즐겨찾기 추가
            favorites.append(client)
            toastText = "즐겨찾기를 추가했습니다"
        }
        showToast = true
    }

    private func deleteClient(_ client: Client) {
        if let idx = allUngrouped.firstIndex(where: { $0.id == client.id }) {
            allUngrouped.remove(at: idx)
        }
        if let fidx = favorites.firstIndex(where: { $0.id == client.id }) {
            favorites.remove(at: fidx)
        }
    }
}

private extension View {
    // ContactsListSection의 applyListRowCleaning과 동일
    func applyListRowCleaning() -> some View {
        self
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview { ContactsView() }

