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
    private let rightTitle: String
    private let onRightTap: () -> Void
    private let onClose: () -> Void
    private let isRightEnabled: Bool

    // Theme
    private var background: Color = Color("Background")
    private var separator: Color = Color("BackgoundDisabled")
    private var foreground: Color = .black
    private var height: CGFloat = 52

    init(
        title: String,
        rightTitle: String,
        isRightEnabled: Bool = true,
        onRightTap: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.rightTitle = rightTitle
        self.isRightEnabled = isRightEnabled
        self.onRightTap = onRightTap
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                // Left/right lane (left: close, right: confirm)
                HStack(spacing: 0) {
                    leftButton
                    Spacer(minLength: 0)
                    rightButton
                }
                .frame(height: height)
                .padding(.horizontal, 12)
                .background(background)

                // Center title overlay
                Text(title)
                    .font(.title3)
                    .foregroundColor(foreground)
                    .lineLimit(1)
                    .frame(height: height)
                    .padding(.horizontal, 12)
                    .allowsHitTesting(false)
            }

            Rectangle()
                .fill(separator)
                .frame(height: 1)
        }
    }

    private var leftButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.title4)
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
            Text(rightTitle)
                .font(.body4)
        }
        .buttonStyle(
            TopBarTextButtonStyle(
                isEnabled: isEnabled
            )
        )
        .disabled(!isEnabled)
        .accessibilityLabel(Text(rightTitle))
    }
}

private struct TopBarTextButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let effectivePressed = configuration.isPressed && isEnabled

        let textColor: Color = {
            if !isEnabled { return Color("BackgoundDisabled") }
            if effectivePressed { return Color("PrimaryHover") }
            return Color("Primary")
        }()

        return configuration.label
            .foregroundColor(textColor)
            .frame(height: 44)
            .padding(.horizontal, 8)
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
