//
//  NotesView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesView: View {
    @State private var selectedFilter: NotesFilter = .all
    @State private var clients: [Client] = sampleClients.filter { !$0.notes.isEmpty }
    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var showDeleteDialog: Bool = false
    @State private var clientToDelete: Client?
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            NotesNavigationBar(
                onMenuTap: {
                    // TODO: 메뉴 액션
                }
            )
            
            // Filter Tabs
            NotesFilterTabs(
                selectedFilter: $selectedFilter,
                availableFilters: availableFilters
            )
            
            // Notes List using APEXList
            APEXList(
                clients: filteredClients,
                rowStyle: .note,
                onTap: { client in
                    // TODO: 상세 화면 이동
                    print("Tapped client: \(client.name)")
                },
                onDelete: { client in
                    clientToDelete = client
                    showDeleteDialog = true
                },
                onTogglePin: { client in
                    togglePin(client)
                }
            )
        }
        .background(Color("Background"))
        .confirmationDialog(
            "해당 연락처 노트를\n영구적으로 삭제하겠습니까?",
            isPresented: $showDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let client = clientToDelete {
                    deleteClient(client)
                }
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
    
    // MARK: - Computed Properties
    
    private var allCompanyNames: [String] {
        // 모든 클라이언트에서 회사명 추출 (노트 유무와 관계없이)
        Set(sampleClients.compactMap { $0.company.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    private var availableFilters: [NotesFilterItem] {
        let allFilter = NotesFilterItem(filter: .all, isEnabled: true) // All은 항상 활성화
        let companyFilters = allCompanyNames.map { companyName in
            // 해당 회사에 노트가 있는 클라이언트가 있는지 확인
            let hasNotes = clients.contains { $0.company.trimmingCharacters(in: .whitespacesAndNewlines) == companyName }
            return NotesFilterItem(filter: .company(companyName), isEnabled: hasNotes)
        }
        
        return [allFilter] + companyFilters
    }
    
    private var filteredClients: [Client] {
        let filtered: [Client]
        
        switch selectedFilter {
        case .all:
            filtered = clients
        case .company(let companyName):
            filtered = clients.filter { $0.company.trimmingCharacters(in: .whitespacesAndNewlines) == companyName }
        }
        
        // 핀 고정된 항목을 맨 위로, 그 다음 최신 노트 순으로 정렬
        return filtered.sorted { client1, client2 in
            // 핀이 있는 항목이 우선
            if client1.pin != client2.pin {
                return client1.pin
            }
            
            // 같은 핀 상태라면 최신 노트 순으로
            let date1 = client1.notes.max { $0.uploadedAt < $1.uploadedAt }?.uploadedAt ?? Date.distantPast
            let date2 = client2.notes.max { $0.uploadedAt < $1.uploadedAt }?.uploadedAt ?? Date.distantPast
            return date1 > date2
        }
    }
    
    // MARK: - Actions
    
    private func togglePin(_ client: Client) {
        if let index = clients.firstIndex(where: { $0.id == client.id }) {
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
    }
    
    private func deleteClient(_ client: Client) {
        if let index = clients.firstIndex(where: { $0.id == client.id }) {
            clients.remove(at: index)
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
