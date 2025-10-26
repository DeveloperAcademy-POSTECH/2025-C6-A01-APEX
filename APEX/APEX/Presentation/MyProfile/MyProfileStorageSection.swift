//
//  MyProfileStorageSection.swift
//  APEX
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

struct MyProfileStorageSection: View {
    var usedText: String
    var isPurgeEnabled: Bool
    var onManageTapped: () -> Void
    var onPurgeTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("데이터 및 저장공간")
                .font(.body4)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            row(title: "노트 저장공간 관리", trailing: usedText) {
                onManageTapped()
            }

            HStack(spacing: 12) {
                Text("임시 데이터 삭제")
                    .font(.body2)
                    .foregroundColor(.primary)
                Spacer()
                Button("삭제") { onPurgeTapped() }
                    .font(.body5)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 32)
                    .background(isPurgeEnabled ? Color("Error") : Color("BackgroundDisabled"))
                    .cornerRadius(6)
                    .disabled(!isPurgeEnabled)
            }
            .frame(height: 44)
        }
    }

    private func row(title: String, trailing: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body2)
                    .foregroundColor(.primary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.body5)
                        .foregroundColor(.gray)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MyProfileStorageSection(
        usedText: "5.62GB",
        isPurgeEnabled: false,
        onManageTapped: { },
        onPurgeTapped: { }
    )
    .padding()
    .background(Color("Background"))
}

