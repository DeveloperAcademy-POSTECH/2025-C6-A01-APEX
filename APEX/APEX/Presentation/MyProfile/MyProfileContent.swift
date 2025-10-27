//
//  MyProfileContent.swift
//  APEX
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

// MARK: - Primary Action View

struct MyProfilePrimaryActionView: View {
    let title: String
    var action: () -> Void

    var body: some View {
        APEXButton(title, action: action)
            .apexButtonTheme(
                .init(
                    font: .title4,
                    foregroundEnabled: .white,
                    foregroundDisabled: .white.opacity(0.6),
                    backgroundEnabled: Color("Primary"),
                    backgroundPressed: Color("PrimaryHover"),
                    backgroundDisabled: Color("BackgroundDisabled"),
                    cornerRadius: 4,
                    height: 56,
                    horizontalPadding: 0
                )
            )
    }
}

// MARK: - Contacts Section

struct MyProfileContactsSection: View {
    var email: String?
    var phone: String?
    var linkedin: String?

    var onTapEmail: (String) -> Void
    var onTapPhone: (String) -> Void
    var onTapLinkedIn: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topSeparator

            if let email, !email.isEmpty {
                ContactCard {
                    item(label: "이메일", value: email, isLink: true) {
                        onTapEmail(email)
                    }
                }
            }
            if let phone, !phone.isEmpty {
                ContactCard {
                    item(label: "전화번호 / Mobile", value: phone, isLink: true) {
                        onTapPhone(phone)
                    }
                }
            }
            if let linkedin, !linkedin.isEmpty {
                ContactCard {
                    item(label: "링크드인 URL", value: linkedin, isLink: true) {
                        onTapLinkedIn(linkedin)
                    }
                }
            }
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 8) // 섹션 내부 좌우 패딩
    }

    @ViewBuilder
    private func item(label: String, value: String, isLink: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.body6)
                .foregroundColor(.gray)

            Button(action: action) {
                Text(value)
                    .font(.body2)
                    .foregroundColor(isLink ? Color("Primary") : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private var topSeparator: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

private struct ContactCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 0)
            .padding(.vertical, 0)
            .background(Color("Background"))
    }
}

// MARK: - Section Metrics

private enum MyProfileSectionMetrics {
    static let titleHeight: CGFloat = 33     // 섹션 타이틀 전용 높이
    static let rowHeight: CGFloat = 40       // 일반 행 높이
    static let interRowSpacing: CGFloat = 4
    static let verticalPadding: CGFloat = 10
}

// MARK: - Storage Section

struct MyProfileStorageSection: View {
    var usedText: String
    var isPurgeEnabled: Bool
    var onManageTapped: () -> Void
    var onPurgeTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MyProfileSectionMetrics.interRowSpacing) {
            topSeparator

            // 타이틀 위 간격 10
            Spacer().frame(height: 10)

            // Title
            Text("데이터 및 저장공간")
                .font(.body1)
                .foregroundColor(.black)
                .frame(height: MyProfileSectionMetrics.titleHeight, alignment: .center)
                .border(.red)

            // Row: 노트 저장공간 관리
            Button(action: onManageTapped) {
                HStack(spacing: 12) {
                    Text("노트 저장공간 관리")
                        .font(.body3)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !usedText.isEmpty {
                        Text(usedText)
                            .font(.body3)
                            .foregroundColor(.gray)
                    }
                }
                .frame(height: MyProfileSectionMetrics.rowHeight)
                .contentShape(Rectangle())
                .border(.red)
            }
            .buttonStyle(.plain)

            // Row: 임시 데이터 삭제 (텍스트 동일, 우측 버튼)
            HStack(spacing: 12) {
                Text("임시 데이터 삭제")
                    .font(.body3)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PurgeButton(isEnabled: isPurgeEnabled, action: onPurgeTapped)
            }
            .frame(height: MyProfileSectionMetrics.rowHeight)
            .border(.red)
        }
        .padding(.vertical, MyProfileSectionMetrics.verticalPadding)
        .padding(.horizontal, 8) // 섹션 내부 좌우 패딩
        .border(.red)
    }

    private var topSeparator: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Purge Button (지정 스펙 적용)

private struct PurgeButton: View {
    let isEnabled: Bool
    let action: () -> Void

    @State private var pressed: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Text("삭제")
                    .font(.body3)
                    .foregroundColor(foregroundColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 0)
            .frame(height: 30, alignment: .center)
            .background(backgroundColor)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isEnabled { withAnimation(.easeInOut(duration: 0.12)) { pressed = true } } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.12)) { pressed = false } }
        )
    }

    private var backgroundColor: Color {
        if !isEnabled { return Color("BackgroundDisabled") }
        let base = Color(red: 1, green: 0.91, blue: 0.9)
        return pressed ? base.opacity(0.9) : base
    }

    private var foregroundColor: Color {
        if !isEnabled { return Color("BackgroundDisabled").opacity(0.6) }
        return Color("Error")
    }
}

// MARK: - App Info Section

struct MyProfileAppInfoSection: View {
    var versionText: String
    var onTermsTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MyProfileSectionMetrics.interRowSpacing) {
            topSeparator

            // 타이틀 위 간격 10
            Spacer().frame(height: 10)

            Text("앱 정보")
                .font(.body1)
                .foregroundColor(.black)
                .frame(height: MyProfileSectionMetrics.titleHeight, alignment: .center)

            Button(action: onTermsTapped) {
                HStack(spacing: 12) {
                    Text("약관 및 정책")
                        .font(.body3)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: MyProfileSectionMetrics.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Text("현재 버전")
                    .font(.body3)
                    .foregroundColor(.gray)
                Spacer()
                Text(versionText)
                    .font(.body3)
                    .foregroundColor(.gray)
            }
            .frame(height: MyProfileSectionMetrics.rowHeight)
        }
        .padding(.vertical, MyProfileSectionMetrics.verticalPadding)
        .padding(.horizontal, 8) // 섹션 내부 좌우 패딩
    }

    private var topSeparator: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Danger Zone Section

struct MyProfileDangerZoneSection: View {
    var onLogout: () -> Void
    var onDeleteAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MyProfileSectionMetrics.interRowSpacing) {
            topSeparator

            // 타이틀이 없는 섹션이라 상단 간격 10을 바로 콘텐츠 위에 적용할지 여부를 결정할 수 있습니다.
            // 만약 동일한 상단 여백 10이 필요하면 아래 Spacer를 유지하세요.
            Spacer().frame(height: 10)

            Button(action: onLogout) {
                HStack {
                    Text("로그아웃")
                        .font(.body3)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: MyProfileSectionMetrics.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDeleteAccount) {
                HStack {
                    Text("계정 탈퇴")
                        .font(.body3)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: MyProfileSectionMetrics.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, MyProfileSectionMetrics.verticalPadding)
        .padding(.horizontal, 8) // 섹션 내부 좌우 패딩
    }

    private var topSeparator: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Bundle Extension

extension Bundle {
    func apexVersionString() -> String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v)"
    }
}

// MARK: - Previews

#Preview("Primary Action") {
    MyProfilePrimaryActionView(title: "메모하기") { }
        .padding()
        .background(Color("Background"))
}

#Preview("Contacts Section") {
    MyProfileContactsSection(
        email: "user@example.com",
        phone: "+82 010-2360-6221",
        linkedin: "https://linkedin.com/in/username",
        onTapEmail: { _ in },
        onTapPhone: { _ in },
        onTapLinkedIn: { _ in }
    )
    .padding()
    .background(Color("Background"))
}

#Preview("Storage Section") {
    MyProfileStorageSection(
        usedText: "5.62GB",
        isPurgeEnabled: true,
        onManageTapped: { },
        onPurgeTapped: { }
    )
    .padding()
    .background(Color("Background"))
}

#Preview("App Info Section") {
    MyProfileAppInfoSection(
        versionText: "1.0.0",
        onTermsTapped: { }
    )
    .padding()
    .background(Color("Background"))
}

#Preview("Danger Zone Section") {
    MyProfileDangerZoneSection(
        onLogout: { },
        onDeleteAccount: { }
    )
    .padding()
    .background(Color("Background"))
}
