import SwiftUI

/// 재사용 가능한 섹션 컨테이너(Favorites/All 공통)
struct ContactsListSection: View {
    let title: String
    let count: Int?
    @Binding var isExpanded: Bool
    let clients: [Client]
    var groupHeaderTitle: String? = nil
    var groupByCompany: Bool = false
    var onToggleFavorite: (Client) -> Void
    var onDelete: ((Client) -> Void)? = nil
    var onTapRow: ((Client) -> Void)? = nil
    var showsSeparatorBelowHeader: Bool = false   // Favorites만 true (섹션 하단에 색 있는 구분선 표시)

    private enum Metrics {
        static let groupTitleHeight: CGFloat = 20
        static let horizontalPadding: CGFloat = 16
        static let gap: CGFloat = 8                 // 기본 간격(헤더 아래, 기타)
        static let groupGapAfterTitle: CGFloat = 4  // Ungrouped 아래 전용 간격
        static let separatorHeight: CGFloat = 2     // 구분선 높이를 8에서 2로 변경
    }

    var body: some View {
        Group {
            headerRow

            if isExpanded {
                if groupByCompany {
                    // 회사명 기준으로 그룹핑. 공백/빈 문자열은 "Ungrouped" 처리
                    let grouped = Dictionary(grouping: clients) { client in
                        let trimmed = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? "Ungrouped" : trimmed
                    }
                    let sortedKeys: [String] = grouped.keys.sorted { lhs, rhs in
                        if lhs == "Ungrouped" { return false }
                        if rhs == "Ungrouped" { return true }
                        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                    }

                    ForEach(sortedKeys, id: \.self) { key in
                        // 그룹 헤더 위에 8pt 패딩 추가
                        gapRow
                        groupHeaderRow(title: key)
                        groupGapRow
                        let groupClients = grouped[key] ?? []
                        ForEach(groupClients) { client in
                            ContactsRow(
                                client: client,
                                onToggleFavorite: { onToggleFavorite(client) },
                                onDelete: { onDelete?(client) },
                                onTap: { onTapRow?(client) }
                            )
                            .applyListRowCleaning()
                        }
                    }
                } else {
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
                }
            }
            
            // 4) Favorites 전용: 구분선을 토글 상태와 관계없이 항상 표시
            if showsSeparatorBelowHeader {
                gapRow                  // 구분선 위쪽 간격 8
                separatorBarRow         // 색 있는 구분선(높이 2)
                    .onAppear {
                        print("🐛 Separator appearing for \(title) - clients count: \(clients.count)")
                    }
                gapRow                  // 구분선 아래쪽 간격 8
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
            .font(.body2)                       // All과 같은 폰트로 변경
            .foregroundColor(Color("GrayLabel"))             // Gray 색상으로 변경
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
            .onAppear {
                print("🐛 separatorBarRow rendered with height: \(Metrics.separatorHeight)")
            }
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
                    groupHeaderTitle: nil,
                    groupByCompany: true,
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
