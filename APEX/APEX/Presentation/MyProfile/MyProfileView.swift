//
//  MyProfileView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/27/25.
//

import SwiftUI

struct MyProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @Binding var client: DummyClient
    @StateObject private var viewModel: MyProfileViewModel
    // Removed local NavigationLink push states and moved UI state to ViewModel

    init(client: Binding<DummyClient>) {
        self._client = client
        self._viewModel = StateObject(wrappedValue: MyProfileViewModel(client: client))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                // 헤더 섹션 (패딩 없음 - 전체 화면 너비 사용)
                MyProfileHeaderView(
                    client: viewModel.adaptedClient,
                    page: $viewModel.currentPageIndex,
                    onCardTapped: { viewModel.send(.showCardViewer(true)) }
                )
                
                // 프라이머리 액션
                MyProfilePrimaryActionView(title: "메모하기") {
                    let id = viewModel.ensureMyChatClientId()
                    router.push(.chat(id))
                }
                    .accessibilityLabel("메모하기")
                    .apexButtonTheme(
                        APEXButtonTheme(
                            cornerRadius: 15,
                            height: 56
                        )
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 연락처 섹션
                MyProfileContactsSection(
                    email: client.email,
                    phone: client.phoneNumber,
                    linkedin: client.linkedinURL,
                    openExternal: { url in viewModel.openExternal(url) },
                    copyToPasteboard: { text in viewModel.copyToPasteboard(text) }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 32)

                // 저장공간 섹션
                VStack(spacing: 0) {
                    MyProfileSectionSeparator()
                        .padding(.top, 32)
                    
                    MyProfileStorageSection(
                        usedText: viewModel.usedSizeText,
                        isPurgeEnabled: viewModel.isPurgeEnabledState,
                        onManageTapped: { router.push(.dataManagement) },
                        onPurgeTapped: { viewModel.send(.tapPurge) }
                    )
                    .padding(.vertical, 10)
                }
                .padding(.horizontal, 16)

                // 앱 정보 섹션
                VStack(spacing: 0) {
                    MyProfileSectionSeparator()
                        .padding(.top, 32)
                    
                    MyProfileAppInfoSection(
                        versionText: Bundle.main.apexVersionString(),
                        onTermsTapped: { /* TODO: 약관 화면/URL */ }
                    )
                    .padding(.vertical, 10)
                }
                .padding(.horizontal, 16)

                // 위험 구역 섹션
                VStack(spacing: 0) {
                    MyProfileSectionSeparator()
                        .padding(.top, 32)
                    
                    MyProfileDangerZoneSection(
                        onLogout: { /* TODO */ },
                        onDeleteAccount: { router.push(.unsubscribe) }
                    )
                    .padding(.vertical, 10)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)  // 마지막 여백
            }
        }
        .background(Color("Background"))
        .safeAreaBar(edge: .top) {
            MyProfileNavigationBar(
                title: "\(client.surname)\(client.name)",
                onBack: { router.pop() },
                onEdit: { viewModel.send(.presentEdit(true)) }
            )
        }
        .sheet(isPresented: $viewModel.isPresentingEdit) {
            MyProfileEditSheet(
                client: client,
                onCancel: { },
                onSave: { updated in
                    let previousEmail = self.client.email
                    viewModel.persistClientUpdate(updated, previousEmail: previousEmail)
                }
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
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
                images: [
                    client.nameCardFront ?? Image("CardL"),
                    client.nameCardBack  ?? Image("CardL")
                ],
                onClose: { viewModel.send(.showCardViewer(false)) }
            )
        }
        // Hidden NavigationLink removed; Router handles navigation
        .task {
            viewModel.send(.refreshUsage)
        }
        .onAppear { viewModel.send(.onAppear) }
        .alert("임시 데이터를 삭제하겠습니까", isPresented: $viewModel.showPurgeConfirm) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                viewModel.send(.confirmPurge)
            }
        } message: {
            Text("케시에 임시 저장된 기타 데이터를 삭제하고 정리합니다. 노트 내 텍스트, 사진, 동영상, 음성메시지 파일은 그대로 유지됩니다")
        }
    }
}

#Preview {
    @Previewable @State var client: DummyClient = sampleMyProfileClient

    MyProfileView(client: $client)
}
