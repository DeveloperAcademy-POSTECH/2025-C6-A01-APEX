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
    @ObservedObject private var store = ClientsStore.shared
    let clientId: UUID
    @Binding var client: DummyClient
    @StateObject private var viewModel: ProfileDetailViewModel
    @State private var shouldEndMemoEditing = false
    // Removed local NavigationLink push states and moved UI state to ViewModel

    // 내 프로필 여부 확인
    private var isMyProfile: Bool {
        let myId = ClientsStore.shared.clients.first?.id
        return clientId == myId
    }

    init(clientId: UUID, client: Binding<DummyClient>) {
        self.clientId = clientId
        self._client = client
        self._viewModel = StateObject(wrappedValue: ProfileDetailViewModel(clientId: clientId, client: client))
    }

    // Store 기준으로 표시용 Client 구성
    // - store에 실제 Client가 있으면 그대로 사용
    // - 없으면 Dummy에서 텍스트/프로필만 가져오되, 명함(front/back)은 nil로 강제 → 샘플 명함이 표시되지 않도록
    private var displayClient: Client {
        if let fromStore = store.clients.first(where: { $0.id == clientId }) {
            return fromStore
        }
        let d = viewModel.adaptedClient
        return Client(
            id: UUID(), // 표시용 임시 ID (store 미존재 시)
            profile: d.profile,
            nameCardFront: nil,           // 샘플 유입 방지: 폴백에서는 명함 사용 금지
            nameCardBack: nil,            // 샘플 유입 방지
            surname: d.surname,
            name: d.name,
            position: d.position,
            company: d.company,
            department: d.department,
            email: d.email,
            phoneNumber: d.phoneNumber,
            linkedinURL: d.linkedinURL,
            memo: d.memo,
            action: d.action,
            favorite: d.favorite,
            pin: d.pin,
            notes: [],
            industry: d.industry,
            address: d.address,
            faxNumber: d.faxNumber,
            revenue: d.revenue,
            employees: d.employees,
            additionalEmails: d.additionalEmails,
            additionalPhones: d.additionalPhones,
            additionalURLs: d.additionalURLs
        )
    }

    // CardViewer 열기 여부 판단도 displayClient 기준으로
    private var hasRealImagesForViewer: Bool {
        return displayClient.profile != nil
            || displayClient.nameCardFront != nil
            || displayClient.nameCardBack != nil
    }

    var body: some View {
        List {
            // 헤더 섹션 (패딩 없음 - 전체 화면 너비 사용)
            Section {
                MyProfileHeaderView(
                    client: displayClient,
                    page: $viewModel.currentPageIndex,
                    onCardTapped: {
                        if hasRealImagesForViewer {
                            viewModel.send(.showCardViewer(true))
                        }
                    }
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // 프라이머리 액션
            Section {
                MyProfilePrimaryActionView(title: "메모하기") {
                    // Go to Contacts tab and replace current route with chat,
                    // so popping from chat returns to Contacts instead of profile detail
                    NotificationCenter.default.post(name: .apexSelectContacts, object: nil)
                    router.replace(with: .chat(clientId))
                }
                    .accessibilityLabel("메모하기")
                    .apexButtonTheme(
                        APEXButtonTheme(
                            cornerRadius: 15,
                            height: 56
                        )
                    )
                    .buttonStyle(.plain)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: false)
            }
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // 연락처 섹션
            Section {
                MyProfileContactsSection(
                    email: (store.clients.first(where: { $0.id == clientId })?.email) ?? client.email,
                    phone: (store.clients.first(where: { $0.id == clientId })?.phoneNumber) ?? client.phoneNumber,
                    linkedin: (store.clients.first(where: { $0.id == clientId })?.linkedinURL) ?? client.linkedinURL,
                    openExternal: { url in
                        viewModel.openExternal(url)
                    },
                    copyToPasteboard: { text in
                        viewModel.copyToPasteboard(text)
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

            // 메모 섹션 (내 프로필이 아닌 경우에만 표시)
            if !isMyProfile {
                Section {
                    ProfileDetailMemoSection(
                        memo: Binding(
                            get: { client.memo ?? "" },
                            set: { newValue in
                                client.memo = newValue.isEmpty ? nil : newValue
                                // 실시간 저장을 위해 ViewModel에 업데이트 알림
                                viewModel.updateMemo(newValue.isEmpty ? nil : newValue)
                            }
                        ),
                        shouldEndEditing: shouldEndMemoEditing
                    )
                }
                .listRowInsets(
                    EdgeInsets(
                        top: 24,
                        leading: 16,
                        bottom: 16,
                        trailing: 16
                    )
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .environment(\.defaultMinListRowHeight, 0)
        .listRowSpacing(0)
        .contentShape(Rectangle())
        .onTapGesture {
            // 메모 외부 영역을 터치하면 편집 완료
            shouldEndMemoEditing.toggle()
        }
        .safeAreaBar(edge: .top) {
            MyProfileNavigationBar(
                title: {
                    let fromStore = store.clients.first(where: { $0.id == clientId })
                    if let fromStore {
                        return fromStore.company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : fromStore.company
                    }
                    return client.company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : client.company
                }(),
                onBack: { router.pop() },
                onEdit: { viewModel.send(.presentEdit(true)) }
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $viewModel.isPresentingEdit) {
            let myId = ClientsStore.shared.clients.first?.id
            let isMe = (clientId == myId)
            MyProfileEditSheet(
                client: client,
                onCancel: { },
                onSave: { updated in
                    let previousEmail = self.client.email
                    viewModel.persistClientUpdate(updated, previousEmail: previousEmail)
                },
                onDelete: {
                    viewModel.deleteClient()
                    router.pop()
                },
                showDeleteButton: !isMe
            )
        }
        .confirmationDialog(
            viewModel.contactDialogTitle,
            isPresented: .init(
                get: { viewModel.showingContactAction != nil },
                set: { if !$0 { viewModel.showingContactAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = viewModel.showingContactAction {
                contactActionButtons(for: action)
            }
            Button("취소", role: .cancel) { }
        }
        .alert("오류", isPresented: .init(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCardViewer) {
            // CardViewer도 store의 실제 Client 기준으로만 구성
            let images: [Image] = {
                var images: [Image] = []
                if let ui = displayClient.profile {
                    images.append(Image(uiImage: ui))
                }
                if let front = displayClient.nameCardFront {
                    images.append(front)
                }
                if let back = displayClient.nameCardBack {
                    images.append(back)
                }
                return images
            }()
            
            if !images.isEmpty {
                CardViewer(
                    images: images,
                    onClose: { viewModel.send(.showCardViewer(false)) },
                    hasProfileFirst: displayClient.profile != nil
                )
            } else {
                Color.clear
                    .onAppear {
                        viewModel.send(.showCardViewer(false))
                    }
            }
        }
        // Hidden NavigationLink removed; Router handles navigation
    }

    // MARK: - Helpers

    @ViewBuilder
    private func contactActionButtons(for action: ProfileContactAction) -> some View {
        switch action {
        case .email(let value):
            Button("메일 보내기") { viewModel.openExternal(URL(string: "mailto:\(value)")) }
            Button("복사하기") { viewModel.copyToPasteboard(value) }
        case .phone(let value):
            Button("전화 걸기") {
                viewModel.openExternal(URL(string: "tel:\(value.filter { !$0.isWhitespace })"))
            }
            Button("복사하기") { viewModel.copyToPasteboard(value) }
        case .link(let value):
            Button("링크 열기") { viewModel.openExternal(URL(string: value)) }
            Button("복사하기") { viewModel.copyToPasteboard(value) }
        }
    }
}

#Preview {
    @Previewable @State var client: DummyClient = sampleMyProfileClient
    ProfileDetailView(clientId: UUID(), client: $client)
}
