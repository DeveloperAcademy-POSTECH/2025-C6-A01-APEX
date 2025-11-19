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
    @State private var isPresentingEdit = false
    @State private var showingContactAction: ContactType?   // 복구: 섹션 콜백 시 사용
    @State private var isShowingCardViewer = false
    @State private var alertMessage: String?
    @State private var currentPageIndex: Int = 0
    @State private var usedSizeText: String = "—"
    @State private var isPurgeEnabledState: Bool = false
    @State private var showPurgeConfirm: Bool = false
    // Removed local NavigationLink push states

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
            department: client.department,
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
            },
            industry: client.industry,
            address: client.address,
            faxNumber: client.faxNumber,
            revenue: client.revenue,
            employees: client.employees,
            additionalEmails: client.additionalEmails,
            additionalPhones: client.additionalPhones,
            additionalURLs: client.additionalURLs
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                // 헤더 섹션 (패딩 없음 - 전체 화면 너비 사용)
                MyProfileHeaderView(
                    client: adaptedClient,
                    page: $currentPageIndex,
                    onCardTapped: { isShowingCardViewer = true }
                )
                
                // 프라이머리 액션
                MyProfilePrimaryActionView(title: "메모하기") { openMyChat() }
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
                    usedText: usedSizeText,
                    isPurgeEnabled: isPurgeEnabledState,
                    onManageTapped: { router.push(.dataManagement) },
                    onPurgeTapped: { showPurgeConfirm = true }
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
                    onDeleteAccount: { router.push(.unsubscribe) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 32)
                .padding(.bottom, 16)  // 마지막 여백
            }
        }
        .background(Color("Background"))
        .safeAreaBar(edge: .top) {
            MyProfileNavigationBar(
                title: "\(client.surname)\(client.name)",
                onBack: { router.pop() },
                onEdit: { isPresentingEdit = true }
            )
        }
        .sheet(isPresented: $isPresentingEdit) {
            MyProfileEditSheet(
                client: client,
                onCancel: { },
                onSave: { updated in
                    let previousEmail = self.client.email
                    self.client = updated
                    persistClientUpdate(updated, previousEmail: previousEmail)
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
        // Hidden NavigationLink removed; Router handles navigation
        .task {
            refreshPurgeEnabled()
            await updateUsedSize()
        }
        .onAppear { refreshPurgeEnabled() }
        .alert("임시 데이터를 삭제하겠습니까", isPresented: $showPurgeConfirm) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                purgeTemporaryData()
            }
        } message: {
            Text("케시에 임시 저장된 기타 데이터를 삭제하고 정리합니다. 노트 내 텍스트, 사진, 동영상, 음성메시지 파일은 그대로 유지됩니다")
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

    // MARK: - Temporary Data Management
    private func refreshPurgeEnabled() {
        isPurgeEnabledState = hasTemporaryData()
    }
    
    private func hasTemporaryData() -> Bool {
        let fm = FileManager.default
        let cacheDir = (try? fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let uploadsDir = cacheDir.appendingPathComponent("APEXUploads", isDirectory: true)
        if let items = try? fm.contentsOfDirectory(at: uploadsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]), !items.isEmpty {
            return true
        }
        // Only consider our app-owned temp subdirectory to avoid system temp noise
        let apexTmpDir = fm.temporaryDirectory.appendingPathComponent("APEXTmp", isDirectory: true)
        if let tmpItems = try? fm.contentsOfDirectory(at: apexTmpDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]), !tmpItems.isEmpty {
            return true
        }
        return false
    }
    
    private func purgeTemporaryData() {
        let fm = FileManager.default
        let cacheDir = (try? fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let uploadsDir = cacheDir.appendingPathComponent("APEXUploads", isDirectory: true)
        if fm.fileExists(atPath: uploadsDir.path) {
            do { try fm.removeItem(at: uploadsDir) } catch { }
        }
        // Remove only our app-owned temp directory
        let apexTmpDir = fm.temporaryDirectory.appendingPathComponent("APEXTmp", isDirectory: true)
        if fm.fileExists(atPath: apexTmpDir.path) {
            try? fm.removeItem(at: apexTmpDir)
        }
        URLCache.shared.removeAllCachedResponses()
        LinkPreviewLoader.clearCache()
        refreshPurgeEnabled()
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

    private func updateUsedSize() async {
        do {
            let text = try await RealDataUsageService().totalMediaSizeText()
            await MainActor.run { usedSizeText = text }
        } catch { }
    }

    private func openMyChat() {
        let emailKey = client.email ?? ""
        if let me = ClientsStore.shared.clients.first(where: { ($0.email ?? "") == emailKey }) {
            router.push(.chat(me.id))
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
            department: client.department,
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
        // Prefer updating by email when possible
        let candidates = [updated.email, previousEmail].compactMap { $0 }.filter { !$0.isEmpty }
        if let key = candidates.first,
           let existing = ClientsStore.shared.clients.first(where: { ($0.email ?? "") == key }) {
            let newClient = Client(
                id: existing.id,
                profile: updated.profile,
                nameCardFront: updated.nameCardFront,
                nameCardBack: updated.nameCardBack,
                surname: updated.surname,
                name: updated.name,
                position: updated.position,
                company: updated.company,
                department: updated.department,
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
            return
        }
        
        // Fallback: update the reserved "my profile" slot (index 0) by id
        if let first = ClientsStore.shared.clients.first {
            let newClient = Client(
                id: first.id,
                profile: updated.profile,
                nameCardFront: updated.nameCardFront,
                nameCardBack: updated.nameCardBack,
                surname: updated.surname,
                name: updated.name,
                position: updated.position,
                company: updated.company,
                department: updated.department,
                email: updated.email,
                phoneNumber: updated.phoneNumber,
                linkedinURL: updated.linkedinURL,
                memo: updated.memo,
                action: first.action,
                favorite: first.favorite,
                pin: first.pin,
                notes: first.notes
            )
            ClientsStore.shared.update(newClient)
        }
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
