//
//  APEXTextFieldStyle.swift
//  APEX
//
//  Created by 조운경 on 10/12/25.
//

import SwiftUI

// MARK: - Theme

struct APEXTextFieldTheme: Equatable {
    var textFont: Font
    var labelFont: Font
    var helperFont: Font

    var textColor: Color
    var placeholderColor: Color
    var labelColor: Color
    var helperColor: Color
    var errorColor: Color
    var successColor: Color

    var lineNormal: Color
    var lineFocused: Color
    var lineError: Color
    var background: Color

    init(
        textFont: Font = .title4,
        labelFont: Font = .caption1,
        helperFont: Font = .caption1,
        textColor: Color = .black,
        placeholderColor: Color = Color("BackgoundDisabled"),
        labelColor: Color = .gray,
        helperColor: Color = .gray,
        errorColor: Color = Color("Error"),
        successColor: Color = Color("Primary"),
        lineNormal: Color = Color("BackgoundDisabled"),
        lineFocused: Color = Color("Primary"),
        lineError: Color = Color("Error"),
        background: Color = Color("Background")
    ) {
        self.textFont = textFont
        self.labelFont = labelFont
        self.helperFont = helperFont
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.labelColor = labelColor
        self.helperColor = helperColor
        self.errorColor = errorColor
        self.successColor = successColor
        self.lineNormal = lineNormal
        self.lineFocused = lineFocused
        self.lineError = lineError
        self.background = background
    }
}

private struct APEXTextFieldThemeKey: EnvironmentKey {
    static let defaultValue: APEXTextFieldTheme = .init()
}

extension EnvironmentValues {
    var apexTextFieldTheme: APEXTextFieldTheme {
        get { self[APEXTextFieldThemeKey.self] }
        set { self[APEXTextFieldThemeKey.self] = newValue }
    }
}

extension View {
    func apexTextFieldTheme(_ theme: APEXTextFieldTheme) -> some View {
        environment(\.apexTextFieldTheme, theme)
    }
}

// MARK: - State

enum APEXTextFieldState: Equatable {
    case normal(helper: String? = nil)
    case error(message: String? = nil)
    case success(message: String? = nil)

    var helperText: String? {
        switch self {
        case .normal(let helper): return helper
        case .error(let message): return message
        case .success(let message): return message
        }
    }
}

// MARK: - Style

enum APEXTextFieldKind {
    case singleLine
    case multiLine(minHeight: CGFloat = 144)
}

// MARK: - Component

struct APEXTextField: View {
    // Required
    private let kind: APEXTextFieldKind
    private let placeholder: String
    @Binding private var text: String

    // Options
    private var label: String?
    private var state: APEXTextFieldState
    private var isRequired: Bool
    private var isDisabled: Bool
    private var showsClearButton: Bool
    private var onEditingEndValidate: ((String) -> APEXTextFieldState)?
    private var success: Bool?
    private var error: Bool?

    // Focus
    @FocusState private var focused: Bool
    @State private var hadFocusOnce: Bool = false

    @Environment(\.apexTextFieldTheme) private var theme

    // Backward compatible convenience init similar to old API
    init(
        style: Style = .field,
        label: String? = nil,
        placeholder: String,
        text: Binding<String>,
        isRequired: Bool = false,
        guide: String? = nil,
        showSuccess: Bool? = nil,
        showError: Bool? = nil
    ) {
        self.kind = (style == .field) ? .singleLine : .multiLine()
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.state = .normal(helper: guide)
        self.isRequired = isRequired
        self.isDisabled = false
        self.showsClearButton = true
        self.onEditingEndValidate = nil
        self.success = showSuccess
        self.error = showError
    }

    // New designated init
    init(
        kind: APEXTextFieldKind = .singleLine,
        label: String? = nil,
        placeholder: String,
        text: Binding<String>,
        state: APEXTextFieldState = .normal(helper: nil),
        isRequired: Bool = false,
        isDisabled: Bool = false,
        showsClearButton: Bool = true,
        onEditingEndValidate: ((String) -> APEXTextFieldState)? = nil,
        showSuccess: Bool? = nil,
        showError: Bool? = nil
    ) {
        self.kind = kind
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.state = state
        self.isRequired = isRequired
        self.isDisabled = isDisabled
        self.showsClearButton = showsClearButton
        self.onEditingEndValidate = onEditingEndValidate
        self.success = showSuccess
        self.error = showError
    }

    enum Style { case field, editor }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                HStack(spacing: 4) {
                    Text(label)
                        .font(theme.labelFont)
                        .foregroundColor(labelColor)
                    if isRequired {
                        Text("*")
                            .font(theme.labelFont.weight(.semibold))
                            .foregroundColor(theme.errorColor)
                    }
                }
            }

            switch kind {
            case .singleLine:
                singleLineField
            case .multiLine(let minHeight):
                multiLineEditor(minHeight: minHeight)
            }

            if let helper = helperText, !helper.isEmpty {
                Text(helper)
                    .font(theme.helperFont)
                    .foregroundColor(helperColor)
                    .padding(.top, 4)
            }
        }
        .opacity(isDisabled ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.2), value: focused)
        .animation(.easeInOut(duration: 0.2), value: internalState)
        .onChange(of: focused) { newFocus in
            if newFocus { hadFocusOnce = true }
            if !newFocus {
                if let validate = onEditingEndValidate {
                    internalState = validate(text)
                } else if isRequired {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty, hadFocusOnce {
                        internalState = .error(message: nil)
                    } else if !trimmed.isEmpty {
                        internalState = .success(message: nil)
                    }
                }
            }
        }
    }

    // MARK: - Private
    private var hasLabelOrHelper: Bool {
        if label != nil { return true }
        if let helper = helperText, !helper.isEmpty { return true }
        return false
    }

    private var textFont: Font {
        if !hasLabelOrHelper { return .body2 }
        if case .multiLine = kind { return .body2 }
        return .title4
    }

    @State private var internalState: APEXTextFieldState = .normal(helper: nil)

    private var effectiveState: APEXTextFieldState {
        if error == true { return .error(message: nil) }
        if success == true { return .success(message: nil) }
        switch state {
        case .normal(let helper) where helper == nil: return internalState
        default: return state
        }
    }

    private var lineColor: Color {
        switch effectiveState {
        case .error: return theme.lineError
        default: return focused ? theme.lineFocused : theme.lineNormal
        }
    }

    private var helperColor: Color {
        switch effectiveState {
        case .error: return theme.errorColor
        case .success: return theme.successColor
        default: return theme.helperColor
        }
    }

    private var labelColor: Color {
        switch effectiveState {
        case .error: return theme.errorColor
        default: return focused ? theme.lineFocused : theme.labelColor
        }
    }

    private var helperText: String? { effectiveState.helperText }

    private var showSuccessIcon: Bool {
        if case .success = effectiveState { return true }
        return false
    }

    private var showErrorIcon: Bool {
        if case .error = effectiveState { return true }
        return false
    }

    private var singleLineField: some View {
        HStack(spacing: 8) {
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(theme.placeholderColor))
                .textFieldStyle(.plain)
                .font(textFont)
                .foregroundColor(theme.textColor)
                .disabled(isDisabled)
                .focused($focused)

            if showsClearButton, focused, !text.isEmpty, !isDisabled {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.placeholderColor)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else if showSuccessIcon {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.successColor)
                    .transition(.opacity)
            } else if showErrorIcon {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(theme.errorColor)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(lineColor)
                .animation(.easeInOut(duration: 0.2), value: lineColor)
        }
    }

    private func multiLineEditor(minHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(textFont)
                .foregroundColor(theme.textColor)
                .frame(minHeight: minHeight)
                .disabled(isDisabled)
                .focused($focused)
                .padding(.vertical, 4)

            if text.isEmpty && !focused {
                Text(placeholder)
                    .font(textFont)
                    .foregroundColor(theme.placeholderColor)
                    .padding(.top, 10)
                    .padding(.leading, 6)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .inset(by: 0.5)
                .stroke(lineColor, lineWidth: 1)
                .animation(.easeInOut(duration: 0.2), value: lineColor)
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @State var text1: String = ""
        @State var text2: String = ""
        @State var intro: String = ""

        var body: some View {
            VStack(spacing: 24) {
                APEXTextField(
                    style: .field,
                    label: "성 / Surname",
                    placeholder: "성 입력",
                    text: $text1,
                    isRequired: true,
                    guide: "안내문구"
                )
                .padding()

                APEXTextField(
                    kind: .singleLine,
                    placeholder: "닉네임 입력",
                    text: $text2,
                )
                .apexTextFieldTheme(
                    .init(
                        successColor: Color("Primary"),
                        lineFocused: Color("Primary")
                    )
                )

                APEXTextField(
                    kind: .multiLine(minHeight: 144),
                    label: "소개 / Bio",
                    placeholder: "자기소개를 입력해주세요",
                    text: $intro,
                    state: .normal(helper: "최대 200자")
                )
            }
            .padding()
        }
    }

    return PreviewContainer()
}
