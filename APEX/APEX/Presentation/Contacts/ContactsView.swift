//
//  ContentView.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI

struct ContactsView: View {
    // MARK: - Local state (임시 데이터 가공 및 UI 상태)
    @State private var myProfile: Client? = nil
    @State private var favorites: [Client] = sampleClients.filter { $0.favorite }
    @State private var allUngrouped: [Client] = sampleClients

    @State private var isMyProfileExpanded: Bool = false
    @State private var isFavoritesExpanded: Bool = false
    @State private var isAllExpanded: Bool = false

    @State private var showToast: Bool = false

    // Design tokens
    private var labelGray: Color { Color("Gray") }

    var body: some View {
        VStack(spacing: 0) {
            ContactsTopBar(title: "Contacts") {
                onPlusTap()
            }

            ScrollView {
                VStack(spacing: 16) {
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

                    // 그룹 헤더 텍스트 톤도 통일
                    Text("Ungrouped")
                        .font(.body5)
                        .foregroundColor(labelGray) // 변경: 회색 토큰 적용
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .opacity(0) // 위 ContactsListSection가 자체적으로 표시 중이면 이 블록은 제거해도 됩니다.
                }
                .padding(.vertical, 12)
                .padding(.bottom, 20)
                .background(Color("Background"))
            }
        }
        .apexToast(
            isPresented: $showToast,
            image: Image(systemName: "plus"),
            text: "준비 중입니다",
            buttonTitle: "확인",
            duration: 1.6
        ) { }
        .onAppear {
            isMyProfileExpanded = false
            isFavoritesExpanded = false
            isAllExpanded = false
        }
    }

    private func onPlusTap() { showToast = true }

    private func toggleFavorite(_ client: Client) {
        if let idx = favorites.firstIndex(where: { $0.id == client.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(client)
        }
    }
}

#Preview {
    ContactsView()
}
