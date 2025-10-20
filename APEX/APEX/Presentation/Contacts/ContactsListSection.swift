import SwiftUI

/// 재사용 가능한 섹션 컨테이너(Favorites/All 공통)
struct ContactsListSection: View {
    let title: String
    let count: Int?
    @Binding var isExpanded: Bool
    let clients: [Client]
    var groupHeaderTitle: String? = nil
    var onToggleFavorite: (Client) -> Void
    var onTapRow: ((Client) -> Void)? = nil

    private let verticalSpacingBetweenRows: CGFloat = 8
    private let groupHeaderHorizontalPadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 8) {
            ContactsSectionHeader(
                title: title,
                countText: count.map(String.init),
                isExpanded: $isExpanded
            )

            if isExpanded {
                if let groupHeaderTitle {
                    Text(groupHeaderTitle)
                        .font(.body5)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, groupHeaderHorizontalPadding)
                }

                VStack(spacing: verticalSpacingBetweenRows) {
                    ForEach(clients) { client in
                        ContactsRow(
                            client: client,
                            onToggleFavorite: { onToggleFavorite(client) },
                            onTap: { onTapRow?(client) }
                        )
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    StatefulPreviewWrapper(false) { isExpanded in
        ContactsListSection(
            title: "All",
            count: sampleClients.count,
            isExpanded: isExpanded,
            clients: sampleClients,
            groupHeaderTitle: "Ungrouped",
            onToggleFavorite: { _ in }
        )
    }
}
