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
        static let menuButtonSize: CGFloat = 36
        static let menuIconSize: CGFloat = 16
        static let itemSpacing: CGFloat = 10
        static let toggleScale: CGFloat = 0.9
    }

    @State private var isCompanyEnabled: Bool = false

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Text("Notes")
                    .font(.title1)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    // 회사 관리: Text + Spacer + Toggle(우측 끝)
                    Button(action: { }) {
                        HStack(spacing: Metrics.itemSpacing) {
                            Text("회사 관리")
                                .font(.body2)
                                .foregroundColor(.primary)

                            Spacer(minLength: 0)

                            Toggle("", isOn: $isCompanyEnabled)
                                .labelsHidden()
                                .fixedSize()               // 토글 자체 크기 고정
                                .scaleEffect(Metrics.toggleScale)
                                // .padding(.trailing, -2) // 더 붙이고 싶으면 -2~-4 사이로 조정
                        }
                        .contentShape(Rectangle())
                    }

                    // 노트 관리
                    Button(action: { onMenuTap() }) {
                        Text("노트 관리")
                            .font(.body2)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                }
                
                label: {
                    ZStack {
                        Circle()
                            .fill(Color("BackgroundSecondary"))
                            .frame(width: Metrics.menuButtonSize, height: Metrics.menuButtonSize)
                        Image(systemName: "ellipsis")
                            .font(.system(size: Metrics.menuIconSize, weight: .semibold))
                            .foregroundColor(.primary)
                            
                    }
                    .contentShape(Circle())
                    
                }
                .menuStyle(.automatic)
                .accessibilityLabel(Text("메뉴"))
                
            }
            .frame(height: Metrics.barContentHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.barHorizontalPadding)
            .padding(.vertical, Metrics.barVerticalPadding)
            
        }
        .frame(maxWidth: .infinity)
        .background(Color("Background"))
        
    }
}

#Preview {
    NotesNavigationBar {
        print("menu item tapped")
    }
    .background(Color("Background"))
}
