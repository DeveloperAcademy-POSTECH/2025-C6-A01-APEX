//
//  ProfileDetailComponents.swift
//  APEX
//
//  Created by AI Assistant on 11/03/25.
//

import SwiftUI

// MARK: - Profile Detail Memo Section

struct ProfileDetailMemoSection: View {
    let memo: String
    
    private var isEmpty: Bool {
        memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 메모 라벨 (외부)
            Text("메모")
                .font(.body5)
                .foregroundColor(.gray)
            
            // 메모 박스 (클릭 불가)
            VStack(alignment: .leading, spacing: 0) {
                if isEmpty {
                    Text("주요 대화")
                        .font(.body2)
                        .foregroundColor(Color("BackgroundDisabled"))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(memo)
                        .font(.body2)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .inset(by: 0.5)
                    .stroke(Color("BackgroundDisabled"), lineWidth: 1)
                
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty Memo") {
    ProfileDetailMemoSection(
        memo: ""
    )
    .padding()
    .background(Color("Background"))
}

#Preview("Filled Memo") {
    ProfileDetailMemoSection(
        memo: "이 사람은 마케팅 팀의 팀장이며, 새로운 프로젝트에 대해 논의했습니다. 다음 미팅은 다음 주 화요일로 예정되어 있습니다."
    )
    .padding()
    .background(Color("Background"))
}
