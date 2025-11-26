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

    // 임시 어댑터 제거: ViewModel이 변환 제공

    var body: some View {
        List {
            // 헤더 섹션 (패딩 없음 - 전체 화면 너비 사용)
            Section {
                MyProfileHeaderView(
                    client: (store.clients.first(where: { $0.id == clientId }) ?? viewModel.adaptedClient),
                    page: $viewModel.currentPageIndex,
                    onCardTapped: { viewModel.send(.showCardViewer(true)) }
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // 각 컴포넌트를 개별 Section으로 분리 (MyProfileView와 동일한 방식)

            // 프라이머리 액션
            Section {
                MyProfilePrimaryActionView(title: "메모하기") { router.push(.chat(clientId)) }
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
                // 24-메모-4-컨텐츠-16, 16-8-컨텐츠-8-16 구조
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .environment(\.defaultMinListRowHeight, 0)  // 최소 높이 제거
        .listRowSpacing(0)  // Row 간격 제거
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
                }, // 직접 삭제 처리
                showDeleteButton: !isMe  // 내 프로필이면 삭제 버튼 숨김
            )
        }
        // 기존 액션시트 유지(컴파일/동작 보장). Menu 전환 후 제거 예정.
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
            CardViewer(
                images: {
                    var images: [Image] = []
                    if let ui = client.profile {
                        images.append(Image(uiImage: ui))
                    }
                    if let front = client.nameCardFront { images.append(front) }
                    if let back = client.nameCardBack { images.append(back) }
                    return images
                }(),
                onClose: { viewModel.send(.showCardViewer(false)) },
                hasProfileFirst: client.profile != nil
            )
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
