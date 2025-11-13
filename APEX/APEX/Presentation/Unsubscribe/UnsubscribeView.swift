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
                VStack(alignment: .center, spacing: 32) { // 컴포넌트 사이 패딩 32
                    // 1. 상단 타이틀 문구
                    titleSection
                       
                    
                    // 커스텀 디바이더
                    customDivider
                    
                    // 2. 텍스트 박스 (안내 문구)
                    informationTextBox
                      
                        .padding(.top, -14) // 32pt에서 18pt로 조정 (32-18=14)
                    
                    // 3. 동의 체크박스
                    agreementCheckbox
                  
                    
                    // 4. 탈퇴하기 버튼
                    unsubscribeButton

                }
                .padding(.horizontal, 16) // 좌우만 16pt 패딩
                .padding(.bottom, 16)    // 하단만 16pt 패딩
            }
        }
        .background(Color("Background"))
    }
    
    // MARK: - Components
    
    // 1. 상단 타이틀 문구
    private var titleSection: some View {
        VStack(spacing: 8) { // 제목과 설명 사이 패딩 8
            Text("Stash 탈퇴")
                .font(.title1) // title1 사용
                .foregroundColor(Color("BlackLabel")) // blacklabel 색상
                .multilineTextAlignment(.center)

            Text("탈퇴하기 전에 아래 내용을 확인해주세요")
                .font(.body2) // body2 사용
                .foregroundColor(Color("BlackLabel")) // blacklabel 색상
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16) // 상단 추가 패딩만 유지
    }
    
    // 커스텀 디바이더
    private var customDivider: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: 2)
    }
    
    // 2. 텍스트 박스 (안내 문구) - 단순화
    private var informationTextBox: some View {
        VStack {
            Text("여기에 뭐 써야할지 다 같이 고민…")
                .font(.body)
                .foregroundColor(Color("GrayLabel"))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8) // 상하 패딩 8
        .padding(.horizontal, 8) // 좌우 패딩 8
    }
    
    // 3. 동의 체크박스
    private var agreementCheckbox: some View {
        HStack(spacing: 16) { // 체크와 텍스트 사이 패딩 16
            Button {
                agreed.toggle()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color("BackgroundDisabled"), lineWidth: 1) // 선 색상과 두께 1
                        .fill(agreed ? Color.blue : Color.clear)
                        .frame(width: 24, height: 24) // 프레임 크기 24x24
                    
                    if agreed {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
            .buttonStyle(.plain)

            Text("데이터를 모두 삭제하고 탈퇴하겠습니다.")
                .font(.body2) // body2 사용
                .foregroundColor(Color("BlackLabel")) // blacklabel 사용
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 4. 탈퇴하기 버튼
    private var unsubscribeButton: some View {
        APEXButton("탈퇴하기", isEnabled: agreed) {
            // 더미
            dismiss()
        }
        .apexButtonTheme(
            .init(
                font: .body2, // body2 사용
                foregroundEnabled: Color("Error"),
                foregroundDisabled: Color("BackgroundDisabled"), // 비활성 텍스트 색상
                backgroundEnabled: Color("Error").opacity(0.12),
                backgroundPressed: Color("Error").opacity(0.2),
                backgroundDisabled: Color("BackgroundSecondary"),
                cornerRadius: 10, // corner radius 10
                height: 56, // 높이 56으로 수정
                horizontalPadding: 16
            )
        )
    }

    private var topBar: some View {
        ZStack {
            // 버튼들 레이아웃 - 각 버튼에 개별 패딩 적용
            HStack(spacing: 0) {
                // 뒤로 버튼 - SF Pro Medium, 17pt, 44×44px
                Button(action: { router.pop() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                            .frame(width: 44, height: 44)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium, design: .default))
                            .foregroundColor(Color.black)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .accessibilityLabel("뒤로")
                }
                .buttonStyle(.plain)
                .padding(.leading, 16) // 왼쪽 16px 패딩
                
                Spacer()
            }
            
            // 제목을 절대 가운데에 배치 - title5
            Text("계정 탈퇴")
                .font(.title5)
                .foregroundColor(.black)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 0) // 좌우 패딩 제거
        .padding(.vertical, 8)   // 상하 패딩만 유지  
        .background(.white)
    }
}

#Preview {
    UnsubscribeView()
}
