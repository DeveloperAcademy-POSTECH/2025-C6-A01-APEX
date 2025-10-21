import SwiftUI

/// 상세 화면 관련 설정/상태를 보관하거나 편집 진입을 중재하는 컨테이너(필요 시 사용).
/// 나중에 필요: 편집 모드 토글, 임시 값 보관, 저장/취소 로직
struct ProfileDetailSetView: View {
    let client: Client

    // 예: 편집 모드 상태
    @State private var isEditing: Bool = false

    var body: some View {
        ProfileDetailView(client: client)
            .onChange(of: isEditing) { _ in
                // 편집 모드 전환 훅 (연결 예정)
            }
    }
}

#Preview {
    ProfileDetailSetView(client: sampleClients.first!)
}
