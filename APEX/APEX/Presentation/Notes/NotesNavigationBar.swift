//
//  NotesNavigationBar.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesNavigationBar: View {
    let onMenuTap: () -> Void

    private enum Metrics {
        static let barContentHeight: CGFloat = 44
        static let barHorizontalPadding: CGFloat = 16
        static let barVerticalPadding: CGFloat = 8
        static let menuButtonSize: CGFloat = 44  // ContactsView와 동일
        static let menuIconSize: CGFloat = 20    // ContactsView와 동일
        static let itemSpacing: CGFloat = 10
        static let toggleScale: CGFloat = 0.9
    }

    @State private var isCompanyEnabled: Bool = false

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Text("Notes")
                    .font(.title1)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                MenuToolbarButton(
                    size: Metrics.menuButtonSize,
                    iconSize: Metrics.menuIconSize,
                    normalColor: Color("Primary"),
                    pressedColor: Color("PrimaryHover"),
                    onMenuTap: onMenuTap,
                    isCompanyEnabled: $isCompanyEnabled
                )
                .frame(width: Metrics.menuButtonSize, height: Metrics.menuButtonSize, alignment: .trailing)
                .accessibilityLabel(Text("메뉴"))
            }
            .frame(height: Metrics.barContentHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.barHorizontalPadding)
            .padding(.vertical, Metrics.barVerticalPadding)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Menu Toolbar Button

private struct MenuToolbarButton: View {
    @EnvironmentObject private var router: NavigationRouter
    let size: CGFloat
    let iconSize: CGFloat
    let normalColor: Color
    let pressedColor: Color
    let onMenuTap: () -> Void
    @Binding var isCompanyEnabled: Bool

    @State private var isPressed: Bool = false

    private enum Metrics {
        static let itemSpacing: CGFloat = 10
        static let toggleScale: CGFloat = 0.9
    }

    var body: some View {
        Menu {
            // 회사 관리: Text + Spacer + Toggle(우측 끝)
            Button(action: { }) {
                HStack(spacing: Metrics.itemSpacing) {
                    Text("회사 관리")
                        .font(.body2)
                        .foregroundColor(.black)

                    Spacer(minLength: 0)

                    Toggle("", isOn: $isCompanyEnabled)
                        .labelsHidden()
                        .fixedSize()
                        .scaleEffect(Metrics.toggleScale)
                }
                .contentShape(Rectangle())
            }

            // 노트 관리
            Button(action: { router.push(.notesManagement)}) {
                Text("노트 관리")
                    .font(.body2)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)

                Image(systemName: "ellipsis")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(isPressed ? .black : .black)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
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
        print("menu item tapped")
    }
    .background(Color("Background"))
}
