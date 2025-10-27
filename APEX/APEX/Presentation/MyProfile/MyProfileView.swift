//
//  MyProfileView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/27/25.
//

import SwiftUI

struct MyProfileView: View {
    @Binding var client: DummyClient
    @State private var isPresentingEdit = false
    @State private var showingContactAction: ContactType?
    @State private var isShowingCardViewer = false
    @State private var alertMessage: String?
    @State private var currentPageIndex: Int = 0

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
                // DummyClient.notes는 [String]이므로, 최소 Note로 변환
                // 실제 데이터 연결 전까지는 빈 텍스트 Note로 어댑트
                Note(date: Date(), attachment: .text(""))
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) { 
                // 네비게이션 바
                MyProfileNavigationBar(
                    title: "\(client.surname)\(client.name)",
                    onBack: { /* TODO: dismiss/pop */ },
                    onEdit: { isPresentingEdit = true }
                )
                .background(Color("Background"))
                .padding(.top, 16) // 위로 패딩 16
                .padding(.bottom, 8) // 아래로 패딩 8

                // 상단 헤더(프로필/명함/인디케이터/이름/부제까지 포함)
                MyProfileHeaderView(
                    client: adaptedClient,
                    page: $currentPageIndex,
                    onCardTapped: { isShowingCardViewer = true }
                )
                .padding(.top, 4) // 프로필 프레임 위로 4
                // .padding(.bottom, 4) 제거 - 하단 패딩 제거

                // 프라이머리 액션
                MyProfilePrimaryActionView(title: "메모하기") {
                    // TODO: 메모하기 액션
                }
                .padding(.horizontal, 16)
                .padding(.top, 0) // 32pt → 16pt로 맞추기 위해 0으로 설정
                .accessibilityLabel("메모하기")
                .border(.red)

                // 연락처 섹션
                MyProfileContactsSection(
                    email: client.email,
                    phone: client.phoneNumber,
                    linkedin: client.linkedinURL,
                    onTapEmail: { showingContactAction = .email($0) },
                    onTapPhone: { showingContactAction = .phone($0) },
                    onTapLinkedIn: { showingContactAction = .link($0) }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 32) // 메모하기와 연락처 사이 간격

                // 저장공간
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                MyProfileStorageSection(
                    usedText: "5.62GB",
                    isPurgeEnabled: false,
                    onManageTapped: { /* TODO: DataManagementView 시트 띄우기 */ },
                    onPurgeTapped: { /* TODO */ }
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                

                // 앱 정보
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                MyProfileAppInfoSection(
                    versionText: Bundle.main.apexVersionString(),
                    onTermsTapped: { /* TODO: 약관 화면/URL */ }
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .border(.red)

                // 위험 구역
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                MyProfileDangerZoneSection(
                    onLogout: { /* TODO */ },
                    onDeleteAccount: { /* TODO */ }
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .border(.red)
                    
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
