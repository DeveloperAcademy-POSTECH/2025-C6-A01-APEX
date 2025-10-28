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
        // 요구사항: APEXButton 그대로 사용, 추가 커스텀 금지
        APEXButton(title, action: action)
    }
}

// MARK: - Contacts Section (Menu 기반으로 전환)

struct MyProfileContactsSection: View {
    var email: String?
    var phone: String?
    var linkedin: String?

    // 메뉴 액션에서 사용할 헬퍼를 주입받아 사용
    var openExternal: (URL?) -> Void
    var copyToPasteboard: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 첫 표시 항목이 이메일이면 상단 구분선 숨김
            if !(hasEmailFirst) {
                topSeparator
            }

            if let email, !email.isEmpty {
                ContactCard {
                    contactMenu(
                        label: "이메일",
                        value: email,
                        valueTint: Color("Primary"),
                        menu: {
                            Button(action: {}) {
                                Text(email)
                                    .foregroundColor(.secondary)
                            }
                            .disabled(true)
                            
                            Divider()
                            
                            ControlGroup {
                                MenuActionButton(
                                    title: "보내기",
                                    systemImage: "envelope.fill"
                                ) {
                                    openExternal(URL(string: "mailto:\(email)"))
                                }
                                MenuActionButton(
                                    title: "복사",
                                    systemImage: "doc.on.doc.fill"
                                ) {
                                    copyToPasteboard(email)
                                }
                            }
                        }
                    )
                }
            }

            if let phone, !phone.isEmpty {
                ContactCard {
                    contactMenu(
                        label: "전화번호 / Mobile",
                        value: phone,
                        valueTint: Color("Primary"),
                        menu: {
                            Button(action: {}) {
                                Text(phone)
                                    .foregroundColor(.secondary)
                            }
                            .disabled(true)
                            
                            Divider()
                            
                            ControlGroup {
                                MenuActionButton(
                                    title: "전화걸기",
                                    systemImage: "phone.fill"
                                ) {
                                    let digits = phone.filter { !$0.isWhitespace }
                                    openExternal(URL(string: "tel:\(digits)"))
                                }
                                MenuActionButton(
                                    title: "복사",
                                    systemImage: "doc.on.doc.fill"
                                ) {
                                    copyToPasteboard(phone)
                                }
                            }
                        }
                    )
                }
            }

            if let linkedin, !linkedin.isEmpty {
                ContactCard {
                    contactMenu(
                        label: "링크드인 URL",
                        value: linkedin,
                        valueTint: Color("Primary"),
                        menu: {
                            Section {
                                Text(linkedin)
                                    .foregroundColor(.secondary)
                            }
                            Section {
                                ControlGroup {
                                    MenuActionButton(
                                        title: "링크열기",
                                        systemImage: "link.circle.fill"
                                    ) {
                                        openExternal(URL(string: linkedin))
                                    }
                                    MenuActionButton(
                                        title: "복사",
                                        systemImage: "doc.on.doc.fill"
                                    ) {
                                        copyToPasteboard(linkedin)
                                    }
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 8) // 섹션 내부 좌우 패딩
    }

    private var hasEmailFirst: Bool {
        if let email, !email.isEmpty { return true }
        return false
    }

    // 연락처 라벨 + Menu 래퍼 (시스템 Menu 사용 + 호버 상태 유지)
    @ViewBuilder
    private func contactMenu<Content: View>(
        label: String,
        value: String,
        valueTint: Color,
        @ViewBuilder menu: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.body6)
                .foregroundColor(.gray)

            // 시스템 Menu 사용하되 호버 상태 유지
            ContactMenuWithHover(
                value: value,
                valueTint: valueTint,
                menu: menu
            )
            .accessibilityLabel("\(label), \(value)")
            .accessibilityHint("메뉴 보기")
        }
    }

    private var topSeparator: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Contact Menu with Hover State (피그마 스펙 기반)

private struct ContactMenuWithHover<MenuContent: View>: View {
    let value: String
    let valueTint: Color
    @ViewBuilder var menu: () -> MenuContent
    
    @State private var isMenuPresented = false
    
    var body: some View {
        Menu {
            menu()
        } label: {
            ContactValueLabel(text: value, tint: valueTint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 40, alignment: .center)
                .contentShape(Rectangle())
        }
        .menuStyle(.button) // 라벨 유지하는 버튼 스타일
        .menuActionDismissBehavior(.disabled) // 액션 후 자동 닫힘 방지
        .background(
            // 피그마 스펙: 호버 시 RGB(0.952, 0.952, 0.96) 배경
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isMenuPresented ? Color.hoverBackground : .clear)
                .frame(height: 64) // 피그마 스펙 높이
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isMenuPresented = true
                    }
                }
                .onEnded { _ in
                    // 메뉴가 열린 동안 호버 상태 유지 (더 긴 지연)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            isMenuPresented = false
                        }
                    }
                }
        )
    }
}

// 한 줄 값 라벨(회색 박스 대신 텍스트만, 프레스 효과는 상위 buttonStyle에서 처리)
private struct ContactValueLabel: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.body2)
            .foregroundColor(tint)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Menu Action (개별 호버 상태 포함)

private struct MenuActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isPressed ? Color.hoverBackground.opacity(0.7) : .clear)
                )
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Section Metrics

private enum MyProfileSectionMetrics {
    static let titleHeight: CGFloat = 33     // 섹션 타이틀 전용 높이
    static let rowHeight: CGFloat = 40       // 일반 행 높이
    static let interRowSpacing: CGFloat = 4
    static let verticalPadding: CGFloat = 32 // 내부에서 더 이상 사용하지 않지만 남겨둠(참조용)
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

            Spacer().frame(height: 6)

            // Title
            Text("데이터 및 저장공간")
                .font(.body1)
                .foregroundColor(.black)
                .frame(height: MyProfileSectionMetrics.titleHeight, alignment: .center)
                .padding(.horizontal, 8)

            // Row: 노트 저장공간 관리 (공통 PressableRow 사용)
            PressableRow(height: MyProfileSectionMetrics.rowHeight, action: onManageTapped) {
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
            }
            .padding(.horizontal, 8)
            

            // Row: 임시 데이터 삭제 (텍스트 동일, 우측 버튼)
            HStack(spacing: 12) {
                Text("임시 데이터 삭제")
                    .font(.body3)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PurgeButton(isEnabled: isPurgeEnabled, action: onPurgeTapped)
            }
            .frame(height: MyProfileSectionMetrics.rowHeight)
            .padding(.horizontal, 8)

            Spacer().frame(height: 10)
        }
        .padding(.horizontal, 8)
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
        Button(action: {
            if isEnabled { action() }
        }) {
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isEnabled { withAnimation(.easeInOut(duration: 0.12)) { pressed = true } } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.12)) { pressed = false } }
        )
    }

    private var backgroundColor: Color {
        if !isEnabled { return Color("BackgroundSecondary") } // 비활성 배경
        let base = Color(red: 1, green: 0.91, blue: 0.9)
        return pressed ? base.opacity(0.9) : base
    }

    private var foregroundColor: Color {
        if !isEnabled { return .gray } // 비활성 텍스트
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

            Spacer().frame(height: 6)

            Text("앱 정보")
                .font(.body1)
                .foregroundColor(.black)
                .frame(height: MyProfileSectionMetrics.titleHeight, alignment: .center)
                .padding(.horizontal, 8)

            PressableRow(height: MyProfileSectionMetrics.rowHeight, action: onTermsTapped) {
                HStack(spacing: 12) {
                    Text("약관 및 정책")
                        .font(.body3)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 8)

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
            .padding(.horizontal, 8)

            Spacer().frame(height: 10)
        }
        .padding(.horizontal, 8)
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

            Spacer().frame(height: 6)

            PressableRow(height: MyProfileSectionMetrics.rowHeight, action: onLogout) {
                HStack {
                    Text("로그아웃")
                        .font(.body3)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 8)

            PressableRow(height: MyProfileSectionMetrics.rowHeight, action: onDeleteAccount) {
                HStack {
                    Text("계정 탈퇴")
                        .font(.body3)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 8)

            Spacer().frame(height: 10)
        }
        .padding(.horizontal, 8)
    }

    private var topSeparator: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Pressable Row (공통 래퍼)

struct PressableRow<Label: View>: View {
    var height: CGFloat
    var cornerRadius: CGFloat = 4
    var pressedBackground: Color = Color("BackgroundSecondary")
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(height: height)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(
            PressableRowButtonStyle(
                pressedBackground: pressedBackground,
                cornerRadius: cornerRadius
            )
        )
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Pressable Row ButtonStyle (공통)

struct PressableRowButtonStyle: ButtonStyle {
    var pressedBackground: Color = Color("BackgroundSecondary")
    var cornerRadius: CGFloat = 4
    var duration: Double = 0.12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(configuration.isPressed ? pressedBackground : .clear)
            )
            .animation(.easeInOut(duration: duration), value: configuration.isPressed)
    }
}

// MARK: - Utilities

private let hex333333 = Color.RGB(0x33, 0x33, 0x33)

private extension Color {
    static func RGB(_ r: Int, _ g: Int, _ b: Int, opacity: Double = 1.0) -> Color {
        Color(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: opacity
        )
    }
    
    // 피그마 스펙: 호버 배경색 RGB(0.952, 0.952, 0.96)
    static var hoverBackground: Color {
        Color(
            .sRGB,
            red: 0.952,
            green: 0.952,
            blue: 0.96,
            opacity: 1.0
        )
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

#Preview("Contacts Section (Menu)") {
    MyProfileContactsSection(
        email: "user@example.com",
        phone: "+82 010-2360-6221",
        linkedin: "https://linkedin.com/in/username",
        openExternal: { _ in },
        copyToPasteboard: { _ in }
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
