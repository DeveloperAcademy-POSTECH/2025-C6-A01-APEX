import SwiftUI

/// 이메일/전화/링크 등 정보 섹션을 묶어 보여줍니다.
/// 나중에 필요: 탭 시 기본 액션(전화/메일/열기) + 길게 눌러 복사
struct ProfileInfoSection: View {
    let client: Client

    var body: some View {
        VStack(spacing: 16) {
            if let email = client.email, !email.isEmpty {
                ProfileInfoRow(
                    icon: Image(systemName: "envelope"),
                    title: "이메일",
                    value: email,
                    action: { /* 메일 작성 연결 예정 */ },
                    onCopy: { /* 복사 연결 예정 */ }
                )
            }

            if let phone = client.phoneNumber, !phone.isEmpty {
                ProfileInfoRow(
                    icon: Image(systemName: "phone"),
                    title: "전화번호 / Mobile",
                    value: phone,
                    action: { /* 전화 걸기 연결 예정 */ },
                    onCopy: { /* 복사 연결 예정 */ }
                )
            }

            if let link = client.linkedinURL, !link.isEmpty {
                ProfileInfoRow(
                    icon: Image(systemName: "link"),
                    title: "링크드인 URL",
                    value: link,
                    action: { /* 링크 열기 연결 예정 */ },
                    onCopy: { /* 복사 연결 예정 */ }
                )
            }
        }
    }
}

#Preview {
    ProfileInfoSection(client: sampleClients.first!)
}
