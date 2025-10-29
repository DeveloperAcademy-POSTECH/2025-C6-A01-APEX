//
//  NotesNavigationBar.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

/// Notes 전용 상단 바 (Contacts 스타일 적용)
struct NotesNavigationBar: View {
    let onMenuTap: () -> Void

    private enum Metrics {
        static let barContentHeight: CGFloat = 44
        static let barHorizontalPadding: CGFloat = 16
        static let barVerticalPadding: CGFloat = 8
        static let menuButtonSize: CGFloat = 44
        static let menuIconSize: CGFloat = 20
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Text("Notes")
                    .font(.title1)
                    .foregroundColor(Color("Dark"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                MenuToolbarButton(
                    size: Metrics.menuButtonSize,
                    iconSize: Metrics.menuIconSize,
                    action: onMenuTap
                )
                .frame(width: Metrics.menuButtonSize, height: Metrics.menuButtonSize, alignment: .trailing)
                .accessibilityLabel(Text("메뉴"))
            }
            .frame(height: Metrics.barContentHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.barHorizontalPadding)
            .padding(.vertical, Metrics.barVerticalPadding)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .background(Color("Background"))
    }
}

// MARK: - Toolbar Menu Button (ContactsView 스타일 적용)
private struct MenuToolbarButton: View {
    let size: CGFloat
    let iconSize: CGFloat
    let action: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)

                Image(systemName: "ellipsis")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(Color("Dark"))
                    .opacity(isPressed ? 0.8 : 1.0)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = false }
                }
        )
    }
}

#Preview {
    NotesNavigationBar {
        print("Menu tapped")
    }
    .background(Color("Background"))
}
