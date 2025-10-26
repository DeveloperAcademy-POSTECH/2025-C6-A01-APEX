//
//  MyProfileDangerZoneSection.swift
//  APEX
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

struct MyProfileDangerZoneSection: View {
    var onLogout: () -> Void
    var onDeleteAccount: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            buttonRow(title: "로그아웃", action: onLogout)
            buttonRow(title: "계정 탈퇴", action: onDeleteAccount)
        }
    }

    private func buttonRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body2)
                    .foregroundColor(.primary)
                Spacer()
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MyProfileDangerZoneSection(onLogout: { }, onDeleteAccount: { })
        .padding()
        .background(Color("Background"))
}

