//
//  MyProfileView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/27/25.
//

import SwiftUI

struct MyProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var client: DummyClient
    @State private var isPresentingEdit = false
    @State private var showingContactAction: ContactType?   // 복구: 섹션 콜백 시 사용
    @State private var isShowingCardViewer = false
    @State private var alertMessage: String?
    @State private var currentPageIndex: Int = 0
    @State private var isPushingChat: Bool = false
    @State private var chatClientId: UUID?
    @State private var chatTitle: String = ""

    // 임시 어댑터: DummyClient -> Client (헤더뷰 연결용)
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
        ScrollView {
            VStack(spacing: 0) {
                // 네비게이션 바
                MyProfileNavigationBar(
                    title: "\(client.surname)\(client.name)",
                    onBack: { dismiss() },
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
                MyProfilePrimaryActionView(title: "메모하기") { openMyChat() }
                .padding(.horizontal, 16)
                .padding(.top, 0)
                .accessibilityLabel("메모하기")

                // 연락처 섹션
                // 섹션 시그니처 변경에 맞춰 openExternal / copyToPasteboard 유틸 콜백을 전달
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

                // 저장공간 섹션
                MyProfileStorageSection(
                    usedText: "5.62GB",
                    isPurgeEnabled: false,
                    onManageTapped: { /* TODO: DataManagementView 시트 띄우기 */ },
                    onPurgeTapped: { /* TODO */ }
                )
                .padding(.horizontal, 16)
                .padding(.top, 32)

                // 앱 정보 섹션
                MyProfileAppInfoSection(
                    versionText: Bundle.main.apexVersionString(),
                    onTermsTapped: { /* TODO: 약관 화면/URL */ }
                )
                .padding(.horizontal, 16)
                .padding(.top, 32)

                // 위험 구역 섹션
                MyProfileDangerZoneSection(
                    onLogout: { /* TODO */ },
                    onDeleteAccount: { /* TODO */ }
                )
                .padding(.horizontal, 16)
                .padding(.top, 32)
            }
        }
        .background(Color("Background"))
        .sheet(isPresented: $isPresentingEdit) {
            MyProfileEditSheet(
                client: client,
                onCancel: { },
                onSave: { updated in
                    self.client = updated
                }
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
        .background(
            NavigationLink(
                isActive: $isPushingChat,
                destination: {
                    if let id = chatClientId {
                        let initial = ClientsStore.shared.clients.first(where: { $0.id == id })?.notes ?? []
                        ChattingView(clientId: id, chatTitle: chatTitle, initialNotes: initial)
                            .toolbar(.hidden, for: .navigationBar)
                            .toolbar(.hidden, for: .tabBar)
                    } else {
                        EmptyView()
                    }
                },
                label: { EmptyView() }
            )
            .hidden()
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

    private func openMyChat() {
        let emailKey = client.email ?? ""
        chatTitle = "\(client.name) \(client.surname)"
        if let me = ClientsStore.shared.clients.first(where: { ($0.email ?? "") == emailKey }) {
            chatClientId = me.id
            isPushingChat = true
            return
        }
        // Insert myself if missing, then open
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
        chatClientId = newClient.id
        isPushingChat = true
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

    MyProfileView(client: $client)
}
