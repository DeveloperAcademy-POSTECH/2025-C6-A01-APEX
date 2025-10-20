import SwiftUI

/// 연락처 리스트의 한 행(공통)
struct ContactsRow: View {
    let client: Client
    var onToggleFavorite: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    private let rowHeight: CGFloat = 64
    private let avatarSize: CGFloat = 48
    private let horizontalPadding: CGFloat = 16

    // Design tokens
    private var labelGray: Color { Color("Gray") }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(client.name) \(client.surname)")
                        .font(.body2)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.body6)
                        .foregroundColor(labelGray) // 변경: 회색 토큰 적용
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, horizontalPadding)
            .frame(height: rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    }

    private var subtitle: String {
        let trimmed = client.position?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed! : "untitled"
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
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
    }
}

#Preview {
    ContactsRow(
        client: sampleClients.first!,
        onToggleFavorite: { },
        onTap: { }
    )
}
