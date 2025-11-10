//
//  UnsubscribeView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/27/25.
//

import SwiftUI

struct UnsubscribeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @State private var agreed = false

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stash 탈퇴")
                        .font(.title3)
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Text("탈퇴하기 전에 아래 내용을 확인해주세요")
                        .font(.body6)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)

                    Divider().padding(.horizontal, 16)

                    // 여기에 안내문 추가 가능
                    Text("여기에 뭐 써야할지 다 같이 고민…")
                        .font(.body5)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)

                    HStack(spacing: 8) {
                        Button {
                            agreed.toggle()
                        } label: {
                            Image(systemName: agreed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(agreed ? Color("Primary") : .gray)
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .buttonStyle(.plain)

                        Text("데이터를 모두 삭제하고 탈퇴하겠습니다.")
                            .font(.body2)
                    }
                    .padding(.horizontal, 16)

                    APEXButton("탈퇴하기", isEnabled: agreed) {
                        // 더미
                        dismiss()
                    }
                    .apexButtonTheme(
                        .init(
                            font: .title4,
                            foregroundEnabled: Color("Error"),
                            foregroundDisabled: Color("Error").opacity(0.4),
                            backgroundEnabled: Color("Error").opacity(0.12),
                            backgroundPressed: Color("Error").opacity(0.2),
                            backgroundDisabled: Color("BackgroundSecondary"),
                            cornerRadius: 8,
                            height: 52,
                            horizontalPadding: 16
                        )
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.vertical, 16)
            }
        }
        .background(Color("Background"))
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 0) {
            // 뒤로 버튼 (MyProfile 스타일)
            Button(action: { router.pop() }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        .frame(width: 44, height: 44)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color.black)
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .accessibilityLabel("뒤로")
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(.white)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    UnsubscribeView()
}
