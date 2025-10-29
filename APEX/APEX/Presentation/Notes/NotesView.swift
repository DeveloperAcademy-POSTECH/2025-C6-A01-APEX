//
//  NotesView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesView: View {
    @State private var selectedFilter: NotesFilter = .all
    @State private var clients: [Client] = sampleClients
    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var showDeleteDialog: Bool = false
    @State private var clientToDelete: Client?

    var body: some View {
        VStack(spacing: 0) {
            // Notes 전용 네비게이션 바(ContactsTopBar 스타일 변형)
            NotesNavigationBar {
                // 메뉴(ellipsis) 액션
                print("Notes menu tapped")
            }

            // 필터 탭
            NotesFilterTabs(
                selectedFilter: $selectedFilter,
                availableFilters: availableFilters
            )

            // 리스트
            NotesListView(
                clients: clients,
                selectedFilter: $selectedFilter,
                onTogglePin: { client in
                    togglePin(client)
                },
                onDelete: { client in
                    clientToDelete = client
                    showDeleteDialog = true
                }
            )
            .padding(.vertical, 24)
        }
        .background(Color(UIColor.systemBackground))
        .confirmationDialog(
            "해당 연락처 노트를\n영구적으로 삭제하겠습니까?",
            isPresented: $showDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let client = clientToDelete { deleteClient(client) }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("연락처 내 모든 노트와 파일이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.\n\n위 내용을 모두 확인했습니다.")
        }
        .apexToast(
            isPresented: $showToast,
            image: Image(systemName: "pin"),
            text: toastText,
            buttonTitle: "되돌리기",
            duration: 1.6
        ) { }
    }

    // MARK: - Filters

    private var companyNamesWithNotes: [String] {
        Set(
            clients
                .map { $0.company.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        .sorted()
    }

    private var availableFilters: [NotesFilterItem] {
        let allFilter = NotesFilterItem(filter: .all, isEnabled: true)
        let companyFilters = companyNamesWithNotes.map { NotesFilterItem(filter: .company($0), isEnabled: true) }
        return [allFilter] + companyFilters
    }

    // MARK: - Actions

    private func togglePin(_ client: Client) {
        guard let index = clients.firstIndex(where: { $0.id == client.id }) else { return }
        clients[index] = Client(
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
            pin: !client.pin,
            notes: client.notes
        )
        toastText = client.pin ? "핀을 해제했습니다" : "핀을 추가했습니다"
        presentToast()
    }

    private func deleteClient(_ client: Client) {
        if let index = clients.firstIndex(where: { $0.id == client.id }) {
            clients.remove(at: index)
        }
        if case .company(let name) = selectedFilter,
           !companyNamesWithNotes.contains(name) {
            selectedFilter = .all
        }
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

#Preview {
    NotesView()
}
