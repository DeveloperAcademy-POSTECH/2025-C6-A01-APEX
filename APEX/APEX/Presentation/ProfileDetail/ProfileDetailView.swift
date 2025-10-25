//
//  ProfileDetailView.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import SwiftUI

/// 프로필 상세 화면 엔트리. 외부에서 Client를 주입받아 하위 섹션을 조립합니다.
/// 나중에 필요: onBack, onEdit 액션 연결, 메모 바인딩, 링크/전화/이메일 액션 연결
struct ProfileDetailView: View {
    let client: Client

    // 로컬 상태(임시)
    @State private var memoText: String = ""
    @State private var currentPage: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            ProfileDetailNavigationBar(
                title: client.company,
                onBack: { /* 연결 예정 */ },
                onEdit: { /* 연결 예정 */ }
            )

            ScrollView {
                VStack(spacing: 16) {
                    ProfileHeaderView(
                        client: client,
                        onTapMemo: { /* 연결 예정 */ }
                    )

                    if client.nameCardFront != nil {
                        ProfileCarouselView(
                            images: [client.nameCardFront].compactMap { $0 },
                            currentPage: $currentPage
                        )
                    }

                    ProfileInfoSection(client: client)

                    ProfileMemoSection(
                        text: $memoText,
                        characterLimit: 100
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color("Background"))
        }
        .background(Color("Background"))
    }
}

#Preview {
    ProfileDetailView(client: sampleClients.first!)
}
