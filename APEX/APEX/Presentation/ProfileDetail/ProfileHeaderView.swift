import SwiftUI

/// 프로필 상단 영역: 아바타, 이름/직책/부서, "메모하기" 버튼
/// 나중에 필요: 아바타 탭 액션, 부서/직책 라인 구체화, 버튼 액션 연결
struct ProfileHeaderView: View {
    let client: Client
    var onTapMemo: () -> Void

    private enum Metrics {
        static let avatarSize: CGFloat = 72
        static let spacingV: CGFloat = 8
        static let spacingH: CGFloat = 12
        static let buttonTop: CGFloat = 8
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacingH) {
            avatar

            VStack(alignment: .leading, spacing: Metrics.spacingV) {
                Text("\(client.name) \(client.surname)")
                    .font(.title4)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("\(client.company) \(client.position ?? "")".trimmingCharacters(in: .whitespaces))
                    .font(.body6)
                    .foregroundColor(.gray)
                    .lineLimit(2)

                APEXButton("메모하기") {
                    onTapMemo()
                }
                .padding(.top, Metrics.buttonTop)
            }

            Spacer()
        }
    }

    private var avatar: some View {
        Group {
            if let uiImage = client.profile {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("ProfileS")
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: Metrics.avatarSize, height: Metrics.avatarSize)
        .clipShape(Circle())
    }
}

#Preview {
    ProfileHeaderView(client: sampleClients.first!, onTapMemo: { })
}
