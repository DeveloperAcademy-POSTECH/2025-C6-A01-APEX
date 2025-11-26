//
//  ShareInputBarExt.swift
//  StashShare
//
//  Extracted from ShareSheetView for reuse and organization.
//

import SwiftUI

struct ShareInputBarExt: View {
    @Binding var text: String
    var isEnabled: Bool
    var placeholder: String = "(선택) 메모 입력"
    var onSend: () -> Void
    
    init(
        text: Binding<String>,
        isEnabled: Bool,
        placeholder: String = "(선택) 메모 입력",
        onSend: @escaping () -> Void
    ) {
        self._text = text
        self.isEnabled = isEnabled
        self.placeholder = placeholder
        self.onSend = onSend
    }
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    
    private enum Metrics {
        static let barHeight: CGFloat = 56
        static let horizontalPadding: CGFloat = 12
        static let fieldHeight: CGFloat = 40
        static let fieldRadius: CGFloat = 32
        static let sendSize: CGFloat = 48
        static let sendIcon: CGFloat = 20
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if isEditing {
                Button(
                    action: {
                        isFocused = false
                        isEditing = false
                    },
                    label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)
                    }
                )
                .buttonStyle(.plain)
                .accessibilityLabel(Text("지우기"))
                .glassEffect()
            }
            
            TextField(
                placeholder,
                text: $text,
                onEditingChanged: { editing in
                    isEditing = editing
                },
                onCommit: {
                    if computedIsEnabled { onSend() }
                }
            )
            .font(.body5)
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .frame(height: Metrics.fieldHeight)
            .focused($isFocused)
            .glassEffect(
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: Metrics.fieldRadius,
                    topTrailingRadius: Metrics.fieldRadius
                )
            )
            .submitLabel(.send)
            
            Button(
                action: {
                    if computedIsEnabled { onSend() }
                },
                label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: Metrics.sendIcon, weight: .medium))
                        .foregroundStyle(.white)
                }
            )
            .buttonStyle(.plain)
            .frame(width: Metrics.sendSize, height: Metrics.sendSize)
            .background(computedIsEnabled ? ShareTheme.primary : ShareTheme.backgroundSecondary)
            .clipShape(Circle())
            .disabled(!computedIsEnabled)
            .accessibilityLabel(Text("전송"))
            .glassEffect()
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .frame(height: Metrics.barHeight)
    }
    
    private var computedIsEnabled: Bool { isEnabled }
}


