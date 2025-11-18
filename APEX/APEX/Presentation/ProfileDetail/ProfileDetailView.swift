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
    let clientId: UUID
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
        List {
            // 헤더 섹션 (패딩 없음 - 전체 화면 너비 사용)
            Section {
                MyProfileHeaderView(
                    client: adaptedClient,
                    page: $currentPageIndex,
                    onCardTapped: { isShowingCardViewer = true }
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            
            // 각 컴포넌트를 개별 Section으로 분리 (MyProfileView와 동일한 방식)
            
            // 프라이머리 액션
            Section {
                MyProfilePrimaryActionView(title: "메모하기") { openChatForClient() }
                    .accessibilityLabel("메모하기")
                    .apexButtonTheme(
                        APEXButtonTheme(
                            cornerRadius: 15,
                            height: 56
                        )
                    )
                    .buttonStyle(.plain)  // 기본 스타일 제거
                    .scaleEffect(1.0)  // 빠른 호버 효과를 위한 기본 스케일
                    .animation(.easeInOut(duration: 0.1), value: false)  // 빠른 애니메이션
            }
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // 연락처 섹션
            Section {
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
                .allowsHitTesting(true)  // 내부 터치만 허용
                .contentShape(Rectangle())  // 명시적 터치 영역 정의
            }
            .listRowInsets(EdgeInsets(top: 32, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .buttonStyle(.plain)  // List Row의 기본 터치 효과 비활성화
            .onTapGesture { }  // 빈 탭 제스처로 List Row 선택 방지
            
            // 메모 섹션
            Section {
                ProfileDetailMemoSection(
                    memo: client.memo ?? ""
                )
            }
            .listRowInsets(EdgeInsets(top: 32, leading: 16, bottom: 16, trailing: 16))  // 마지막이라 bottom 16
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .environment(\.defaultMinListRowHeight, 0)  // 최소 높이 제거
        .listRowSpacing(0)  // Row 간격 제거
        .safeAreaBar(edge: .top) {
            MyProfileNavigationBar(
                title: client.autoFormattedName,
                onBack: { router.pop() },
                onEdit: { isPresentingEdit = true }
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isPresentingEdit) {
            let myId = ClientsStore.shared.clients.first?.id
            let isMe = (clientId == myId)
            MyProfileEditSheet(
                client: client,
                onCancel: { },
                onSave: { updated in
                            let previousEmail = self.client.email
                            self.client = updated
                            persistClientUpdate(updated, previousEmail: previousEmail)
                },
                onDelete: { deleteClient() }, // 직접 삭제 처리
                showDeleteButton: !isMe  // 내 프로필이면 삭제 버튼 숨김
            )
        }
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

    // MARK: - Helpers
    
    private func deleteClient() {
        // 실제 삭제 로직 (원본 ID로 삭제)
        ClientsStore.shared.remove(clientId)
        
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
        // 상세보기의 대상은 이미 존재하는 클라이언트이므로 원본 ID로 바로 채팅으로 이동
        router.push(.chat(clientId))
    }

    private func persistClientUpdate(_ updated: DummyClient, previousEmail: String?) {
        // 원본 ID로 정확히 매칭하여 업데이트 (이메일 변경/없음에도 안전)
        guard let existing = ClientsStore.shared.clients.first(where: { $0.id == clientId }) else { return }
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
    ProfileDetailView(clientId: UUID(), client: $client)
}
