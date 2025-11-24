//
//  ProfileDetailComponents.swift
//  APEX
//
//  Created by AI Assistant on 11/03/25.
//

import SwiftUI

// MARK: - Profile Detail Memo Section

struct ProfileDetailMemoSection: View {
    @Binding var memo: String
    @FocusState private var isFocused: Bool
    let shouldEndEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {  // 메모-컨텐츠 간격 4로 조정
            // 메모 라벨
            Text("메모")
                .font(.body5)
                .foregroundColor(.gray)
                .padding(.horizontal, 8)  // 라벨에 좌우 8 패딩 추가
            
            // 편집 가능한 메모 박스
            TextEditor(text: $memo)
                .font(.body2)
                .foregroundColor(.black)
                .scrollContentBackground(.hidden)  // 기본 배경 제거
                .background(Color.clear)
                .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .focused($isFocused)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .inset(by: 0.5)
                        .stroke(Color("BackgroundDisabled"), lineWidth: 1)
                }
                .padding(.horizontal, 8)  // 박스에 좌우 8 패딩 추가
        }
        .onChange(of: shouldEndEditing) { _, newValue in
            if newValue {
                isFocused = false
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty Memo") {
    @Previewable @State var memo = ""
    ProfileDetailMemoSection(memo: $memo, shouldEndEditing: false)
        .padding()
        .background(Color("Background"))
}

#Preview("Filled Memo") {
    @Previewable @State var memo = "이 사람은 마케팅 팀의 팀장이며, 새로운 프로젝트에 대해 논의했습니다. 다음 미팅은 다음 주 화요일로 예정되어 있습니다."
    ProfileDetailMemoSection(memo: $memo, shouldEndEditing: false)
        .padding()
        .background(Color("Background"))
}
