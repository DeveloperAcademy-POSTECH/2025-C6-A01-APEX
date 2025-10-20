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

    var body: some View {
        VStack(spacing: 0) {
            ContactsTopBar(title: "Contacts") { onPlusTap() }

            List {
                // My Profile 섹션
                if let profile = myProfile {
                    Section {
                        ContactsSectionHeader(
                            title: "My Profile",
                            count: 0,
                            isExpanded: $isMyProfileExpanded
                        )
                        // 기본 여백 제거
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                        if isMyProfileExpanded {
                            ContactsRow(client: profile)
                                .listRowSeparator(.hidden)
                                // 기본 여백 제거
                                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                    }
                    // 섹션 단위 기본 간격 제거
                    .listSectionSeparator(.hidden)
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
            .scrollContentBackground(.hidden)
            .background(Color("Background"))
        }
        .apexToast(
            isPresented: $showToast,
            image: Image(systemName: "plus"),
            text: "준비 중입니다",
            buttonTitle: "확인",
            duration: 1.6
        ) { }
    }

    private func onPlusTap() { showToast = true }

    private func toggleFavorite(_ client: Client) {
        if let idx = favorites.firstIndex(where: { $0.id == client.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(client)
        }
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

#Preview { ContactsView() }
