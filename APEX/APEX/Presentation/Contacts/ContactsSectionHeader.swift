import SwiftUI

/// 섹션 제목 + 개수(0이면 숨김) + 접힘/펼침 토글
/// 내부는 좌우 패딩 16, 높이 36 보장. 구분선은 이 컴포넌트에서 그리지 않음.
struct ContactsSectionHeader: View {
    let title: String
    let count: Int
    @Binding var isExpanded: Bool

    private enum Metrics {
        static let horizontalPadding: CGFloat = 16
        static let hStackSpacing: CGFloat = 0
        static let titleCountSpacing: CGFloat = 4
        static let chevronSize: CGFloat = 14
        static let tappableSize: CGFloat = 36    // 최소 터치 영역
        static let headerHeight: CGFloat = 36
    }

    @State private var pressed: Bool = false

    var body: some View {
        Button(action: toggleExpanded) {
            HStack(spacing: Metrics.hStackSpacing) {
                HStack(spacing: Metrics.titleCountSpacing) {
                    titleView
                    if count > 0 { countView }
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: Metrics.chevronSize, weight: .semibold))
                    .frame(width: Metrics.tappableSize, height: Metrics.tappableSize)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Metrics.horizontalPadding) // 좌우 16
            .frame(height: Metrics.headerHeight) // 헤더 높이 36
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .foregroundStyle(.gray) // 시스템 gray
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityHint(accessibilityHint)
        // List 기본 여백/구분선 제거(필수 강제)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        // 필요 시 All 헤더에만 시각적 접착 보정(-1) 적용할 수 있음.
        // .padding(.top, -1)
    }

    // MARK: - Subviews
    private var titleView: some View {
        Text(title)
            .font(.body1)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var countView: some View {
        Text("\(count)")
            .font(.body1)
            .accessibilityLabel("\(count) items")
    }

    // MARK: - Actions
    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.1)) {
            isExpanded.toggle()
        }
    }

    // MARK: - Accessibility
    private var accessibilityTitle: String {
        let state = isExpanded ? "expanded" : "collapsed"
        return count > 0 ? "\(title), \(count), \(state)" : "\(title), \(state)"
    }

    private var accessibilityHint: String {
        isExpanded ? "Collapse section" : "Expand section"
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    struct Wrapper: View {
        @State var expanded = false
        var body: some View {
            List {
                ContactsSectionHeader(title: "Favorites", count: 4, isExpanded: $expanded)
                ContactsSectionHeader(title: "All", count: 600, isExpanded: $expanded)
            }
            .listStyle(.plain)
        }
    }
    return Wrapper()
}
