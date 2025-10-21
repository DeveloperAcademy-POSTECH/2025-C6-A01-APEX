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
            .listRowSpacing(0) // iOS 16/17+에서 유효. 시스템 기본 행 간격 개입 제거
            .environment(\.defaultMinListRowHeight, 1) // 최소 행 높이 낮춰 간격 통제
            .scrollContentBackground(.hidden)
            .background(Color("Background"))
        }
        .border(.red, width: 2.0)
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
            // 이미 즐겨찾기 → 해제
            favorites.remove(at: idx)
            toastText = "즐겨찾기를 해제했습니다"
        } else {
            // 즐겨찾기 추가
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
        // 빠르게 여러 번 호출되더라도 자연스럽게 다시 나타나도록 재설정
        if showToast {
            showToast = false
            // 약간의 지연 후 다시 true로 전환해 transition이 보장되도록
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
    // 파일 로컬 전용으로 정의(다른 파일의 동일 이름 private 확장과 충돌 없음)
    func applyListRowCleaning() -> some View {
        self
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview { ContactsView() }
