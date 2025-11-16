//
//  NotesManagementNavigationBar.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesManagementNavigationBar: View {
    let isSelectionMode: Bool
    let onClose: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // 버튼들 레이아웃 - 각 버튼에 개별 패딩 적용
            HStack(spacing: 0) {
                // 닫기 버튼 - 44×44px, SF Pro Medium 17pt
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium, design: .default))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .glassEffect()
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 16) // 왼쪽 16px 패딩
                
                Spacer()
                
                // 완료 버튼 - 52×44px, title6
                Button(action: onComplete) {
                    Text("완료")
                        .font(.title6)
                        .foregroundColor(.black)
                        .frame(width: 52, height: 44)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .glassEffect()
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16) // 오른쪽 16px 패딩
            }
            
            // 제목을 절대 가운데에 배치 - title5
            Text("노트 관리")
                .font(.title5)
                .foregroundColor(.black)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 0) // 좌우 패딩 제거
        .padding(.vertical, 8)   // 상하 패딩만 유지  
        .background(Color("Background"))
    }
}

#Preview {
    NotesManagementNavigationBar(
        isSelectionMode: false,
        onClose: {},
        onComplete: {}
    )
    .background(Color("Background"))
}
