//
//  APEXButton.swift
//  APEX
//
//  Created by 조운경 on 10/17/25.
//

import SwiftUI

// MARK: - Theme

struct APEXButtonTheme: Equatable {
    var font: Font
    var foregroundEnabled: Color
    var foregroundDisabled: Color

    var backgroundEnabled: Color
    var backgroundPressed: Color
    var backgroundDisabled: Color

    var cornerRadius: CGFloat
    var height: CGFloat
    var horizontalPadding: CGFloat
    
    init(
        font: Font = .title4,
        foregroundEnabled: Color = .white,
        foregroundDisabled: Color = .white.opacity(0.6),
        backgroundEnabled: Color = Color("Primary"),
        backgroundPressed: Color = Color("PrimaryHover"),
        backgroundDisabled: Color = Color("BackgroundDisabled"),
        cornerRadius: CGFloat = 12,
        height: CGFloat = 52,
        horizontalPadding: CGFloat = 16
    ) {
        self.font = font
        self.foregroundEnabled = foregroundEnabled
        self.foregroundDisabled = foregroundDisabled
        self.backgroundEnabled = backgroundEnabled
        self.backgroundPressed = backgroundPressed
        self.backgroundDisabled = backgroundDisabled
        self.cornerRadius = cornerRadius
        self.height = height
        self.horizontalPadding = horizontalPadding
    }
}

private struct APEXButtonThemeKey: EnvironmentKey {
    static let defaultValue: APEXButtonTheme = .init()
}

extension EnvironmentValues {
    var apexButtonTheme: APEXButtonTheme {
        get { self[APEXButtonThemeKey.self] }
        set { self[APEXButtonThemeKey.self] = newValue }
    }
}

extension View {
    func apexButtonTheme(_ theme: APEXButtonTheme) -> some View {
        environment(\.apexButtonTheme, theme)
    }
}

// MARK: - Public API

struct APEXButton: View {
    private let title: String
    private let isEnabled: Bool
    private let action: () -> Void
    private var leading: Image?
    private var trailing: Image?

    @Environment(\.apexButtonTheme) private var theme

    init(
        _ title: String,
        isEnabled: Bool = true,
        leading: Image? = nil,
        trailing: Image? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.leading = leading
        self.trailing = trailing
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let leading { leading }
                Text(title)
                    .font(theme.font)
                if let trailing { trailing }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(
            APEXFilledButtonStyle(isEnabled: isEnabled)
        )
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - ButtonStyle (handles default/pressed/disabled)

private struct APEXFilledButtonStyle: ButtonStyle {
    @Environment(\.apexButtonTheme) private var theme

    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && isEnabled

        let background: Color = {
            if !isEnabled { return theme.backgroundDisabled }            // disabled
            if isPressed { return theme.backgroundPressed }              // pressed
            return theme.backgroundEnabled                               // default
        }()
        
        let foreground: Color = isEnabled ? theme.foregroundEnabled : theme.foregroundDisabled
        let height = theme.height
        
        return configuration.label
            .foregroundColor(foreground)
            .frame(height: height)
            .padding(.horizontal, theme.horizontalPadding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .animation(.easeInOut(duration: 0.15), value: isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        APEXButton("기본 상태") {
            print("tap")
        }
        APEXButton("비활성화", isEnabled: false) { }
    }
    .padding()
}

