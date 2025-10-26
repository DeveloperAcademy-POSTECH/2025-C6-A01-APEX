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
                    cornerRadius: 4, // 디자인 스펙에 맞게 4로 변경
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
        VStack(alignment: .leading, spacing: 16) {
            if let email, !email.isEmpty {
                item(label: "이메일", value: email, isLink: true) {
                    onTapEmail(email)
                }
            }
            if let phone, !phone.isEmpty {
                item(label: "전화번호 / Mobile", value: phone, isLink: true) {
                    onTapPhone(phone)
                }
            }
            if let linkedin, !linkedin.isEmpty {
                item(label: "링크드인 URL", value: linkedin, isLink: true) {
                    onTapLinkedIn(linkedin)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func item(label: String, value: String, isLink: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
}

// MARK: - Storage Section

struct MyProfileStorageSection: View {
    var usedText: String
    var isPurgeEnabled: Bool
    var onManageTapped: () -> Void
    var onPurgeTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("데이터 및 저장공간")
                .font(.body4)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            row(title: "노트 저장공간 관리", trailing: usedText) {
                onManageTapped()
            }

            HStack(spacing: 12) {
                Text("임시 데이터 삭제")
                    .font(.body2)
                    .foregroundColor(.primary)
                Spacer()
                Button("삭제") { onPurgeTapped() }
                    .font(.body5)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 32)
                    .background(isPurgeEnabled ? Color("Error") : Color("BackgroundDisabled"))
                    .cornerRadius(6)
                    .disabled(!isPurgeEnabled)
            }
            .frame(height: 44)
        }
    }

    private func row(title: String, trailing: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body2)
                    .foregroundColor(.primary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.body5)
                        .foregroundColor(.gray)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Info Section

struct MyProfileAppInfoSection: View {
    var versionText: String
    var onTermsTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("앱 정보")
                .font(.body4)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            row(title: "약관 및 정책", trailing: nil, action: onTermsTapped)

            HStack(spacing: 12) {
                Text("현재 버전")
                    .font(.body2)
                    .foregroundColor(.primary)
                Spacer()
                Text(versionText)
                    .font(.body5)
                    .foregroundColor(.gray)
            }
            .frame(height: 44)
        }
    }

    private func row(title: String, trailing: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body2)
                    .foregroundColor(.primary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.body5)
                        .foregroundColor(.gray)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Danger Zone Section

struct MyProfileDangerZoneSection: View {
    var onLogout: () -> Void
    var onDeleteAccount: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            buttonRow(title: "로그아웃", action: onLogout)
            buttonRow(title: "계정 탈퇴", action: onDeleteAccount)
        }
    }

    private func buttonRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body2)
                    .foregroundColor(.primary)
                Spacer()
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
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
        isPurgeEnabled: false,
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