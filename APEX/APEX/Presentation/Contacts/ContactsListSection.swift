import SwiftUI

/// 재사용 가능한 섹션 컨테이너(Favorites/All 공통)
struct ContactsListSection: View {
    let title: String
    let count: Int?
    @Binding var isExpanded: Bool
    let clients: [Client]
    var groupHeaderTitle: String? = nil
    var groupHeaderColor: Color? = nil            // 추가: 그룹 헤더 텍스트 색상 주입
    var onToggleFavorite: (Client) -> Void
    var onDelete: ((Client) -> Void)? = nil
    var onTapRow: ((Client) -> Void)? = nil
    var showsSeparatorBelowHeader: Bool = false   // Favorites만 true

    private enum Metrics {
        static let groupTitleHeight: CGFloat = 20
        static let horizontalPadding: CGFloat = 16
        static let gap: CGFloat = 8
        static let groupGapAfterTitle: CGFloat = 4
        static let separatorHeight: CGFloat = 8
    }

    var body: some View {
        Group {
            headerRow
            gapRow
            if isExpanded {
                if let groupHeaderTitle {
                    groupHeaderRow(title: groupHeaderTitle, color: groupHeaderColor ?? .primary)
                    groupGapRow
                }
                ForEach(clients) { client in
                    ContactsRow(
                        client: client,
                        onToggleFavorite: { onToggleFavorite(client) },
                        onDelete: { onDelete?(client) },
                        onTap: { onTapRow?(client) }
                    )
                    .applyListRowCleaning()
                }
                if showsSeparatorBelowHeader, !clients.isEmpty {
                    gapRow
                    separatorBarRow
                    gapRow
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        Group {
            if !title.isEmpty {
                ContactsSectionHeader(
                    title: title,
                    count: count ?? 0,
                    isExpanded: $isExpanded
                )
            } else {
                EmptyView()
            }
        }
        .applyListRowCleaning()
    }

    private func groupHeaderRow(title: String, color: Color) -> some View {
        Text(title)
            .font(.body1)
            .foregroundColor(color)
            .frame(height: Metrics.groupTitleHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.horizontalPadding)
            .applyListRowCleaning()
    }

    private var gapRow: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: Metrics.gap)
            .applyListRowCleaning()
    }

    private var groupGapRow: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: Metrics.groupGapAfterTitle)
            .applyListRowCleaning()
    }

    private var separatorBarRow: some View {
        Rectangle()
            .fill(Color("BackgroundSecondary"))
            .frame(height: Metrics.separatorHeight)
            .applyListRowCleaning()
    }
}

// MARK: - View Modifiers

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
                ContactsListSection(
                    title: "Favorites",
                    count: 3,
                    isExpanded: $expandedFavorites,
                    clients: sampleClients,
                    onToggleFavorite: { _ in }
                )

                ContactsListSection(
                    title: "",
                    count: 2,
                    isExpanded: $expandedAll,
                    clients: sampleClients,
                    groupHeaderTitle: "TechWave",
                    groupHeaderColor: .black,
                    onToggleFavorite: { _ in }
                )

                ContactsListSection(
                    title: "",
                    count: 1,
                    isExpanded: $expandedAll,
                    clients: sampleClients,
                    groupHeaderTitle: "None",
                    groupHeaderColor: .blue,
                    onToggleFavorite: { _ in }
                )
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .environment(\.defaultMinListRowHeight, 1)
        }
    }
    return Wrapper()
}
