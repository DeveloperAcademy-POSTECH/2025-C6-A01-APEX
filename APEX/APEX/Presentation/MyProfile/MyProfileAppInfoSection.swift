//
//  MyProfileAppInfoSection.swift
//  APEX
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

struct MyProfileAppInfoSection: View {
    var versionText: String
    var onTermsTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("앱 정보")
                .font(.body4)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            row(title: "약관 및 정책", trailing: nil, action: onTermsTapped)

            HStack(spacing: 12) {
                Text("현재 버전")
                    .font(.body2)
                    .foregroundColor(.primary)
                Spacer()
                Text(versionText)
                    .font(.body5)
                    .foregroundColor(.gray)
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

// 접근 범위를 파일 외부에서도 사용 가능하도록 internal(기본)로 공개
extension Bundle {
    func apexVersionString() -> String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? ""
        // 시안은 빌드 번호 노출 없이 버전만 표시하므로 v만 반환
        return b.isEmpty ? v : "\(v)"
    }
}

#Preview {
    MyProfileAppInfoSection(versionText: "1.0.0", onTermsTapped: { })
        .padding()
        .background(Color("Background"))
}
