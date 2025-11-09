//
//  ProfileDetailView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/27/25.
//

import SwiftUI

struct ProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @Binding var client: DummyClient
    @State private var isPresentingEdit = false
    @State private var showingContactAction: ContactType?   // 복구: 섹션 콜백 시 사용
    @State private var isShowingCardViewer = false
    @State private var alertMessage: String?
    @State private var currentPageIndex: Int = 0
    // Removed local NavigationLink push states

    // 임시 어댑터: DummyClient를 Client로 변환 (헤더뷰 연결용)
    private var adaptedClient: Client {
        Client(
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
            notes: client.notes.map { _ in
                // Note 이니셜라이저에 맞게 수정
                Note(uploadedAt: Date(), text: "", bundle: nil)
            }
        )
    }

    var body: some View {
        mainContent
        .background(Color("Background"))
        .sheet(isPresented: $isPresentingEdit) {
            MyProfileEditSheet(
                client: client,
                onCancel: { },
                onSave: { updated in
                            let previousEmail = self.client.email
                            self.client = updated
                            persistClientUpdate(updated, previousEmail: previousEmail)
                },
                onDelete: { deleteClient() }, // 직접 삭제 처리
                showDeleteButton: true  // ProfileDetailView에서만 삭제 버튼 표시
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        // 기존 액션시트 유지(컴파일/동작 보장). Menu 전환 후 제거 예정.
        .confirmationDialog(
            contactDialogTitle,
            isPresented: .init(
                get: { showingContactAction != nil },
                set: { if !$0 { showingContactAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = showingContactAction {
                contactActionButtons(for: action)
            }
            Button("취소", role: .cancel) { }
        }
        .alert("오류", isPresented: .init(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
        .fullScreenCover(isPresented: $isShowingCardViewer) {
            CardViewer(
                images: [
                    client.nameCardFront ?? Image("CardL"),
                    client.nameCardBack  ?? Image("CardL")
                ],
                onClose: { isShowingCardViewer = false }
            )
        }
        // Hidden NavigationLink removed; Router handles navigation
    }

    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 네비게이션 바
                MyProfileNavigationBar(
                    title: client.autoFormattedName,
                    onBack: { router.pop() },
                    onEdit: { isPresentingEdit = true }
                )
                .background(Color("Background"))
                .padding(.top, 16)
                .padding(.bottom, 8)

                // 상단 헤더
                MyProfileHeaderView(
                    client: adaptedClient,
                    page: $currentPageIndex,
                    onCardTapped: { isShowingCardViewer = true }
                )
                .padding(.top, 4)

                // 프라이머리 액션
                MyProfilePrimaryActionView(title: "메모하기") {
                    openChatForClient()
                }
                .padding(.horizontal, 16)
                .padding(.top, 0)
                .accessibilityLabel("메모하기")

                // 연락처 섹션
                MyProfileContactsSection(
                    email: client.email,
                    phone: client.phoneNumber,
                    linkedin: client.linkedinURL,
                    openExternal: { url in
                        openExternal(url)
                    },
                    copyToPasteboard: { text in
                        copyToPasteboard(text)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 32)
                

                // 메모 섹션
                ProfileDetailMemoSection(
                    memo: client.memo ?? ""
                )
                .padding(.horizontal, 24)
                .padding(.top, 24)
            
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func deleteClient() {
        // 실제 삭제 로직
        ClientsStore.shared.remove(convertToClient().id)
        
        // 화면 닫기
        router.pop()
    }
    
    private func convertToClient() -> Client {
        Client(
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

    // MARK: - Helpers

    private var contactDialogTitle: String {
        switch showingContactAction {
        case .email: return "이메일"
        case .phone: return "전화번호"
        case .link:  return "링크"
        case .none:  return ""
        }
    }

    @ViewBuilder
    private func contactActionButtons(for action: ContactType) -> some View {
        switch action {
        case .email(let value):
            Button("메일 보내기") { openExternal(URL(string: "mailto:\(value)")) }
            Button("복사하기") { copyToPasteboard(value) }
        case .phone(let value):
            Button("전화 걸기") {
                openExternal(URL(string: "tel:\(value.filter { !$0.isWhitespace })"))
            }
            Button("복사하기") { copyToPasteboard(value) }
        case .link(let value):
            Button("링크 열기") { openExternal(URL(string: value)) }
            Button("복사하기") { copyToPasteboard(value) }
        }
    }

    private func openExternal(_ url: URL?) {
        guard let url else { alertMessage = "잘못된 주소입니다."; return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success { alertMessage = "열 수 없습니다." }
        }
    }

    private func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    private func openChatForClient() {
        let emailKey = client.email ?? ""
        if let existing = ClientsStore.shared.clients.first(where: { ($0.email ?? "") == emailKey }) {
            router.push(.chat(existing.id))
            return
        }
        let newClient = Client(
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
        ClientsStore.shared.add(newClient, atTop: true)
        router.push(.chat(newClient.id))
    }

    private func persistClientUpdate(_ updated: DummyClient, previousEmail: String?) {
        // Prefer updated email; fallback to previous email
        let candidates = [updated.email, previousEmail].compactMap { $0 }.filter { !$0.isEmpty }
        guard let key = candidates.first else { return }
        guard let existing = ClientsStore.shared.clients.first(where: { ($0.email ?? "") == key }) else { return }
        let newClient = Client(
            id: existing.id,
            profile: updated.profile,
            nameCardFront: updated.nameCardFront,
            nameCardBack: updated.nameCardBack,
            surname: updated.surname,
            name: updated.name,
            position: updated.position,
            company: updated.company,
            email: updated.email,
            phoneNumber: updated.phoneNumber,
            linkedinURL: updated.linkedinURL,
            memo: updated.memo,
            action: existing.action,
            favorite: existing.favorite,
            pin: existing.pin,
            notes: existing.notes
        )
        ClientsStore.shared.update(newClient)
    }
}

// MARK: - Models

private enum ContactType: Equatable {
    case email(String)
    case phone(String)
    case link(String)
}

#Preview {
    @Previewable @State var client: DummyClient = sampleMyProfileClient
    ProfileDetailView(client: $client)
}
