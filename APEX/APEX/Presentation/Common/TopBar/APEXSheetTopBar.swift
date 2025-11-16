//
//  APEXSheetTopBar.swift
//  APEX
//
//  Created by AI Assistant on 10/18/25.
//

import SwiftUI

/// Sheet-style top bar with centered title and a right-aligned action button
struct APEXSheetTopBar: View {
    private let title: String
    private let subtitle: String?
    private let rightTitle: String
    private let onRightTap: () -> Void
    private let onClose: () -> Void
    private let isRightEnabled: Bool
    private let rightIconSystemName: String?
    private let showsRightButton: Bool
    private let leftIconSystemName: String

    // Theme
    private var background: Color = Color("Background")
    private var separator: Color = Color("BackgroundDisabled")
    private var foreground: Color = .black
    private var height: CGFloat = 52

    init(
        title: String,
        subtitle: String? = nil,
        rightTitle: String,
        isRightEnabled: Bool = true,
        onRightTap: @escaping () -> Void,
        onClose: @escaping () -> Void,
        rightIconSystemName: String? = nil,
        showsRightButton: Bool = true,
        leftIconSystemName: String = "xmark"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.rightTitle = rightTitle
        self.isRightEnabled = isRightEnabled
        self.onRightTap = onRightTap
        self.onClose = onClose
        self.rightIconSystemName = rightIconSystemName
        self.showsRightButton = showsRightButton
        self.leftIconSystemName = leftIconSystemName
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                // Left/right lane (left: close, right: confirm)
                HStack(spacing: 0) {
                    leftButton
                    Spacer(minLength: 0)
                    if showsRightButton {
                        rightButton
                    }
                }
                .frame(height: height)
                .padding(.horizontal, 12)

            // Center title overlay with optional subtitle
                VStack(spacing: 2) {
                    Text(title)
                        .font(.title5)
                        .foregroundColor(foreground)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(subtitleColor)
                            .lineLimit(1)
                    }
                }
                .frame(height: height)
                .padding(.horizontal, 12)
                .allowsHitTesting(false)
            }
        }
    }

    private var subtitleColor: Color {
        if let subtitle, subtitle.contains("/") { return Color("Primary") }
        return .gray
    }

    private var leftButton: some View {
        Button(action: onClose) {
            Image(systemName: leftIconSystemName)
                .font(.system(size: 20, weight: .medium, design: .default))
                .foregroundColor(foreground)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect()
        .accessibilityLabel(Text("닫기"))
    }

    private var rightButton: some View {
        let isEnabled = isRightEnabled

        return Button(action: onRightTap) {
            if let icon = rightIconSystemName {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                    Text(rightTitle)
                        .font(.body5)
                }
                .frame(height: 44)
                .padding(.horizontal, 6)
                .glassEffect()
            } else {
                Text(rightTitle)
                    .font(.title6)
                    .foregroundColor(isEnabled ? .black : Color("BackgroundDisabled"))
                    .frame(width: 52, height: 44)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .glassEffect()
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(rightTitle))
    }
}

private struct TopBarTextButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let effectivePressed = configuration.isPressed && isEnabled

        let textColor: Color = {
            if !isEnabled { return Color("BackgroundDisabled") }
            if effectivePressed { return Color("BackgroundSecondary") }
            return .black
        }()

        return configuration.label
            .foregroundColor(textColor)
            .frame(height: 44)
            .padding(6)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.12), value: effectivePressed)
    }
}

#Preview {
    VStack(spacing: 0) {
        // 기본
        APEXSheetTopBar(title: "사진 추가", rightTitle: "완료", onRightTap: { }, onClose: { })
        // 비활성
        APEXSheetTopBar(title: "사진 추가", rightTitle: "완료", isRightEnabled: false, onRightTap: { }, onClose: { })
    }
}
