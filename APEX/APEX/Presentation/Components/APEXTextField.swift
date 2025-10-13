//
//  APEXTextFieldStyle.swift
//  APEX
//
//  Created by 조운경 on 10/12/25.
//

import SwiftUI

struct APEXTextField: View {
    enum Style { case field, editor }
    
    let style: Style
    let label: String?
    let placeholder: String
    @Binding var text: String
    var isRequired: Bool = false
    var guide: String? = nil
    
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @FocusState private var focused: Bool
    @State private var hadFocusOnce: Bool = false
    
    private var labelColor: Color {
        return focused ? .primaryDefault : .gray
    }
    
    private var lineColor: Color {
        if showError { return .error }
        return focused ? .primaryDefault : .backgoundDisabled
    }
    
    private var guideColor: Color {
        return showError ? .error : .gray
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if let label = label {
                Text(label)
                    .font(.caption)
                    .foregroundColor(labelColor)
            }
            
            if style == .field {
                HStack {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .font(.title4)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                    
                    if focused, !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .transition(.opacity)
                    } else if showSuccess {
                        Image(systemName: "checkmark")
                            .foregroundColor(.primaryDefault)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(lineColor)
                }
                .animation(.easeInOut(duration: 0.2), value: focused)
                .animation(.easeInOut(duration: 0.2), value: showError)
                .animation(.easeInOut(duration: 0.2), value: showSuccess)
            } else {
                TextEditor(text: $text)
                    .focused($focused)
                    .font(.title4)
                    .frame(minHeight: 144)
                    .overlay(alignment: .topLeading) {
                        if !focused && text.isEmpty {
                            Text(placeholder)
                                .font(.title4)
                                .foregroundColor(.backgoundDisabled)
                                .padding(.top, 8)
                                .padding(.leading, 10)
                                .allowsHitTesting(false)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: focused)
            }
            
            if let guide {
                Text(guide)
                    .font(.caption)
                    .foregroundColor(guideColor)
                    .padding(.top, 4)
            }
        }
        .onChange(of: focused) { newFocus in
            guard isRequired else {
                showSuccess = false
                showError = false
                return
            }
            if newFocus { // 포커스 진입
                hadFocusOnce = true
                showSuccess = false
                showError = false
            } else { // 포커스 해제
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    showError = hadFocusOnce
                    showSuccess = focused
                } else {
                    showSuccess = true
                    showError = false
                }
            }
        }
    }
}

#Preview {
    APEXTextField(
        style: .field,
        label: "성 / Surname",
        placeholder: "성 입력",
        text: .constant(""),
        guide: "안내문구"
    )
}
