import SwiftUI

/// 연락처 리스트의 한 행(공통)
struct ContactsRow: View {
    let client: Client
    var onToggleFavorite: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    // Style tokens (확정 스펙 반영)
    private enum Metrics {
        static let cellHeight: CGFloat = 64
        static let avatarSize: CGFloat = 48
        static let textBoxHeight: CGFloat = 38
        static let hStackSpacing: CGFloat = 12
        static let nameSubtitleSpacing: CGFloat = 2
        static let contentHorizontalPadding: CGFloat = 16
        static let trailingSpacerMin: CGFloat = 8
        static let cornerRadius: CGFloat = 4
    }

    // 임시 디폴트(직책 없음 표시) - 나중에 제거/변경하기 쉽게 상수로 분리
    private static let placeholderSubtitle = "Designer"

    private var labelGray: Color { Color("Gray") }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .center, spacing: Metrics.hStackSpacing) {
                avatar

                // 텍스트 박스(이름/서브타이틀) 높이 38 고정, 수직 중앙 정렬
                VStack(alignment: .leading, spacing: Metrics.nameSubtitleSpacing) {
                    Text("\(client.name) \(client.surname)")
                        .font(.body2)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.body6)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        
                }
                .frame(height: Metrics.textBoxHeight)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: Metrics.trailingSpacerMin)
            }
            .padding(.horizontal, Metrics.contentHorizontalPadding)
            .frame(height: Metrics.cellHeight) // 셀 전체 높이 64 고정
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .cornerRadius(Metrics.cornerRadius)
        .contentShape(Rectangle())
        // 좌측 스와이프: 즐겨찾기 토글
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if let onToggleFavorite {
                Button {
                    onToggleFavorite()
                } label: {
                    Image(systemName: client.favorite ? "star.slash" : "star")
                }
                .tint(Color("Primary"))
            }
        }
        // 우측 스와이프: 삭제
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .tint(Color("Error"))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(client.name) \(client.surname), \(subtitle)")
    }

    private var subtitle: String {
        let trimmed = client.position?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = trimmed, !value.isEmpty {
            return value
        } else {
            // 직책이 없을 때 임시 표시
            return Self.placeholderSubtitle
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
                    .scaledToFit()
            }
        }
        .frame(width: Metrics.avatarSize, height: Metrics.avatarSize)
        .clipShape(Circle())
    }
}

#Preview {
    ContactsRow(
        client: sampleClients.first!,
        onToggleFavorite: { },
        onDelete: { },
        onTap: { }
    )
}
