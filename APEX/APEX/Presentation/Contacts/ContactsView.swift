//
//  ContentView.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI

struct ContactsView: View {
    // MARK: - Local state (임시 데이터 가공 및 UI 상태)
    @State private var myProfile: Client? = nil // 현재는 없는 상태로 시작
    @State private var favorites: [Client] = sampleClients.filter { $0.favorite }
    @State private var allUngrouped: [Client] = sampleClients

    @State private var isMyProfileExpanded: Bool = false
    @State private var isFavoritesExpanded: Bool = false
    @State private var isAllExpanded: Bool = false

    @State private var showToast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar (심플)
            ContactsTopBar(title: "Contacts") {
                onPlusTap()
            }

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // My Profile 섹션 (데이터가 있을 때만 노출)
                    if let profile = myProfile {
                        VStack(spacing: 8) {
                            ContactsSectionHeader(
                                title: "My Profile",
                                countText: nil,
                                isExpanded: $isMyProfileExpanded
                            )

                            if isMyProfileExpanded {
                                VStack(spacing: 8) {
                                    ContactsRow(client: profile)
                                }
                                .transition(.opacity)
                            }
                        }
                    }

                    // Favorites 섹션 (데이터 없으면 숨김)
                    if !favorites.isEmpty {
                        ContactsListSection(
                            title: "Favorites",
                            count: favorites.count,
                            isExpanded: $isFavoritesExpanded,
                            clients: favorites,
                            onToggleFavorite: { client in
                                toggleFavorite(client)
                            }
                        )
                    }

                    // All 섹션 (항상 노출, 기본 접힘)
                    ContactsListSection(
                        title: "All",
                        count: allUngrouped.count,
                        isExpanded: $isAllExpanded,
                        clients: allUngrouped,
                        groupHeaderTitle: "Ungrouped",
                        onToggleFavorite: { client in
                            toggleFavorite(client)
                        }
                    )
                }
                .padding(.vertical, 12) // 섹션 헤더 상하 여백 기준
                .padding(.bottom, 20)   // 탭바 위 여유
                .background(Color("Background", bundle: .main) ?? Color.white)
            }
        }
        .apexToast(
            isPresented: $showToast,
            image: Image(systemName: "plus"),
            text: "준비 중입니다",
            buttonTitle: "확인",
            duration: 1.6
        ) {
            // 토스트 버튼 탭
        }
        .onAppear {
            // 섹션 기본 상태: 모두 접힘
            isMyProfileExpanded = false
            isFavoritesExpanded = false
            isAllExpanded = false
        }
    }

    // MARK: - Actions
    private func onPlusTap() {
        // 아직 이동화면 미구현 → 토스트로 안내
        showToast = true
    }

    private func toggleFavorite(_ client: Client) {
        // 로컬 상태에서만 토글 반영 (데이터 저장은 추후)
        if let idx = favorites.firstIndex(where: { $0.id == client.id }) {
            // 즐겨찾기 → 해제
            favorites.remove(at: idx)
        } else {
            // 즐겨찾기 → 추가
            favorites.append(client)
        }
        // 실제 모델 변경 없이 Favorites 배열만 관리
    }
}

#Preview {
    ContactsView()
}
