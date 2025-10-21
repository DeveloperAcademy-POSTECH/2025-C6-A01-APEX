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
    var showsSeparatorBelowHeader: Bool = false   // Favorites만 true (섹션 하단에 색 있는 구분선 표시)

    private enum Metrics {
        static let groupTitleHeight: CGFloat = 20
        static let horizontalPadding: CGFloat = 16
        static let gap: CGFloat = 8                 // 기본 간격(헤더 아래, 기타)
        static let groupGapAfterTitle: CGFloat = 4  // Ungrouped 아래 전용 간격
        static let separatorHeight: CGFloat = 8
    }

    var body: some View {
        Group {
            // 1) 섹션 헤더
            headerRow

            // 2) 헤더 아래 고정 간격 8
            gapRow

            // 3) 펼침 상태일 때 내용
            if isExpanded {
                // 3-1) 그룹 헤더(예: Ungrouped)
                if let groupHeaderTitle {
                    groupHeaderRow(title: groupHeaderTitle)
                    groupGapRow // 그룹 헤더 아래만 4로 축소
                }

                // 3-2) 연락처 리스트(행 사이 간격은 0)
                ForEach(clients) { client in
                    ContactsRow(
                        client: client,
                        onToggleFavorite: { onToggleFavorite(client) },
                        onDelete: { onDelete?(client) },
                        onTap: { onTapRow?(client) }
                    )
                    .applyListRowCleaning()
                }

                // 3-3) Favorites 전용: 마지막 연락처 셀 ↔ 구분선 간격 8, 그리고 구분선 ↔ 다음 섹션(All 헤더) 간격 8
                if showsSeparatorBelowHeader, !clients.isEmpty {
                    gapRow                  // 마지막 연락처 셀과 구분선 사이 8
                    separatorBarRow         // 색 있는 구분선(높이 8)
                    gapRow                  // 구분선과 다음 섹션(=All 헤더) 사이 8
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        ContactsSectionHeader(
            title: title,
            count: count ?? 0,
            isExpanded: $isExpanded
        )
        .applyListRowCleaning()
    }

    private func groupHeaderRow(title: String) -> some View {
        Text(title)
            .font(.body1)
            .foregroundColor(.primary)
            .frame(height: Metrics.groupTitleHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.horizontalPadding)
            .applyListRowCleaning()
    }

    // 기본 8pt gap
    private var gapRow: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: Metrics.gap)
            .applyListRowCleaning()
    }

    // Ungrouped 아래 전용 4pt gap
    private var groupGapRow: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: Metrics.groupGapAfterTitle)
            .applyListRowCleaning()
    }

    // 색 있는 구분선(독립 row)
    private var separatorBarRow: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: Metrics.separatorHeight)
            .applyListRowCleaning()
    }
}

// MARK: - View Modifiers (공통 list row 정리)

private extension View {
    func applyListRowCleaning() -> some View {
        self
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    struct Wrapper: View {
        @State var expandedFavorites = true
        @State var expandedAll = true

        var body: some View {
            List {
                // Favorites
                ContactsListSection(
                    title: "Favorites",
                    count: 4,
                    isExpanded: $expandedFavorites,
                    clients: sampleClients,
                    onToggleFavorite: { _ in },
                    onDelete: { _ in },
                    showsSeparatorBelowHeader: true // Favorites만 구분선 표시
                )

                // All
                ContactsListSection(
                    title: "All",
                    count: 600,
                    isExpanded: $expandedAll,
                    clients: sampleClients,
                    groupHeaderTitle: "Ungrouped",
                    onToggleFavorite: { _ in },
                    onDelete: { _ in },
                    showsSeparatorBelowHeader: false // All에는 하단 구분선 없음
                )
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .environment(\.defaultMinListRowHeight, 1)
        }
    }
    return Wrapper()
}
