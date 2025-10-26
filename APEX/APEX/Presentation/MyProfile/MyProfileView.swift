//
//  MyProfileView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/27/25.
//

import SwiftUI

struct MyProfileView: View {
    let client: Client

    // Header page: 0 = Profile, 1 = Card Front, 2 = Card Back
    @State private var page: Int = 0

    // Toast
    @State private var showToast: Bool = false
    @State private var toastText: String = ""

    // Actions (상위에서 주입 가능하도록 콜백 보유)
    var onBack: (() -> Void)?
    var onEdit: ((Client) -> Void)?
    var onMemo: ((Client) -> Void)?
    var onOpenTerms: (() -> Void)?
    var onLogout: (() -> Void)?
    var onDeleteAccount: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 상단 바: 중앙 타이틀, 좌 백 버튼, 우 편집 버튼
            topBar

            ScrollView {
                VStack(spacing: 0) {
                    MyProfileHeaderView(client: client, page: $page)

                    // 메모하기 CTA
                    MyProfilePrimaryActionView(title: "메모하기") {
                        if let onMemo {
                            onMemo(client)
                        } else {
                            toast("메모 화면으로 이동(임시)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                    // 연락처 섹션
                    MyProfileContactsSection(
                        email: client.email,
                        phone: client.phoneNumber,
                        linkedin: client.linkedinURL,
                        onTapEmail: { email in
                            openMail(email)
                        },
                        onTapPhone: { phone in
                            openPhone(phone)
                        },
                        onTapLinkedIn: { url in
                            openURLString(url)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    divider

                    // 데이터 및 저장공간
                    MyProfileStorageSection(
                        usedText: "5.62GB",
                        isPurgeEnabled: false,
                        onManageTapped: {
                            toast("노트 저장공간 관리(임시)")
                        },
                        onPurgeTapped: {
                            toast("임시 데이터 삭제(임시)")
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                    divider

                    // 앱 정보
                    MyProfileAppInfoSection(
                        versionText: Bundle.main.apexVersionString(),
                        onTermsTapped: {
                            if let onOpenTerms { onOpenTerms() }
                            else { toast("약관 및 정책(임시)") }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                    divider

                    // 위험 영역
                    MyProfileDangerZoneSection(
                        onLogout: {
                            if let onLogout { onLogout() }
                            else { toast("로그아웃(임시)") }
                        },
                        onDeleteAccount: {
                            if let onDeleteAccount { onDeleteAccount() }
                            else { toast("계정 탈퇴(임시)") }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .background(Color("Background"))
        }
        .background(Color("Background"))
        .apexToast(
            isPresented: $showToast,
            image: Image(systemName: "info.circle.fill"),
            text: toastText,
            buttonTitle: "확인",
            duration: 1.6
        ) { }
    }

    private var topBar: some View {
        ZStack {
            // 좌/우
            HStack {
                Button {
                    onBack?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title4)
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onEdit?(client)
                } label: {
                    Text("편집")
                        .font(.title6)
                        .frame(width: 44, height: 44)
                        .glassEffect()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(Color("Background"))

            // 중앙 타이틀(닉네임/이름)
            Text(client.name)
                .font(.title3)
                .foregroundColor(.black)
                .lineLimit(1)
                .padding(.horizontal, 80)
                .frame(height: 52)
                .allowsHitTesting(false)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: 8)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers
    private func toast(_ text: String) {
        toastText = text
        if showToast {
            showToast = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                showToast = true
            }
        } else {
            showToast = true
        }
    }

    private func openMail(_ email: String) {
        guard let url = URL(string: "mailto:\(email)") else { return }
        UIApplication.shared.open(url)
    }

    private func openPhone(_ phone: String) {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func openURLString(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    MyProfileView(client: sampleClients.first!)
}

