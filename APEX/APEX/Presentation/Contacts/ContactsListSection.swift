import SwiftUI

/// 재사용 가능한 섹션 컨테이너(Favorites/All 공통)
struct ContactsListSection: View {
    let title: String
    let count: Int?
    @Binding var isExpanded: Bool
    let clients: [Client]
    var groupHeaderTitle: String? = nil
    var onToggleFavorite: (Client) -> Void
    var onDelete: ((Client) -> Void)? = nil
    var onTapRow: ((Client) -> Void)? = nil
    var showsSeparatorBelowHeader: Bool = false   // 이 섹션 끝에 구분선 표시 여부(Favorites만 true)

    private enum Insets {
        static let zero = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    }

    private let groupTitleHeight: CGFloat = 20

    var body: some View {
        // 구분선 위치 결정
        let shouldShowHeaderSeparator = showsSeparatorBelowHeader && (!isExpanded || clients.isEmpty)
        let shouldShowBottomSeparator = showsSeparatorBelowHeader && isExpanded && !clients.isEmpty

        Section {
            // 1) 헤더
            ContactsSectionHeader(
                title: title,
                count: count ?? 0,
                isExpanded: $isExpanded
            )
            .listRowInsets(Insets.zero)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // 접힘/비어있음: 헤더 바로 뒤 구분선
            if shouldShowHeaderSeparator {
                separatorRow
            }

            // 2) 펼쳐졌을 때 그룹 타이틀/셀
            if isExpanded {
                if let groupHeaderTitle {
                    Text(groupHeaderTitle)
                        .font(.body1)
                        .foregroundColor(.primary)
                        .frame(height: groupTitleHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .listRowInsets(Insets.zero)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                ForEach(Array(clients.enumerated()), id: \.element.id) { _, client in
                    ContactsRow(
                        client: client,
                        onToggleFavorite: { onToggleFavorite(client) },
                        onDelete: { onDelete?(client) },
                        onTap: { onTapRow?(client) }
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(Insets.zero)
                    .listRowBackground(Color.clear)
                }

                // 3) 마지막 셀 아래 구분선
                if shouldShowBottomSeparator {
                    separatorRow
                }
            }
        }
        // 섹션 단위 기본 간격 제거(iOS 16+)
        .listSectionSeparator(.hidden)
        .listRowSpacing(0)
    }

    private var separatorRow: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: 8)
            .listRowInsets(Insets.zero)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    struct Wrapper: View {
        @State var expanded = true
        var body: some View {
            List {
                ContactsListSection(
                    title: "Favorites",
                    count: 4,
                    isExpanded: $expanded,
                    clients: sampleClients,
                    onToggleFavorite: { _ in },
                    onDelete: { _ in },
                    showsSeparatorBelowHeader: true // Favorites만 true
                )

                ContactsListSection(
                    title: "All",
                    count: 600,
                    isExpanded: $expanded,
                    clients: sampleClients,
                    groupHeaderTitle: "Ungrouped",
                    onToggleFavorite: { _ in },
                    onDelete: { _ in },
                    showsSeparatorBelowHeader: false // All에는 구분선 없음
                )
            }
            .listStyle(.plain)
        }
    }
    return Wrapper()
}
