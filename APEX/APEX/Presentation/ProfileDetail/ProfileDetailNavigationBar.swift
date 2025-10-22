import SwiftUI

/// 프로필 상세 전용 네비게이션 바
/// - 좌측: 뒤로가기(chevron.left)
/// - 중앙: 고정 타이틀(최대 8자 초과 시 말줄임)
/// - 우측: 설정(gearshape)
/// 디자인 토큰
/// - 전체 높이: 40 (상하 패딩 8 + 내부 컨텐츠 높이 24)
/// - 좌우 패딩: 16
/// - 아이콘 탭 영역: 26x26
/// - 아이콘 폰트: SF Pro 16pt 상응(.system(size: 16, weight: .semibold))
/// - 타이틀 폰트: .title5
/// - 배경: Color("Background")
/// - 구분선: 없음
struct ProfileDetailNavigationBar: View {
    let title: String
    let onBack: () -> Void
    let onEdit: () -> Void

    // Tokens
    private enum Metrics {
        static let totalHeight: CGFloat = 40
        static let contentHeight: CGFloat = 24
        static let iconHeight: CGFloat = 44
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        static let tappableSize: CGFloat = 26
        static let iconSize: CGFloat = 16
    }

    private var background: Color { Color("Background") }
    private var titleColor: Color { .black }
    private var rightIconColor: Color { Color("Primary") }

    var body: some View {
        ZStack {
            // 좌/우 버튼 레인
            HStack(spacing: 0) {
                backButton
                Spacer(minLength: 0)
                editButton
            }
            .frame(height: Metrics.contentHeight)
            .padding(.horizontal, Metrics.horizontalPadding)
            .padding(.vertical, Metrics.verticalPadding)

            // 가운데 타이틀 (버튼 레인 위에 겹쳐 배치)
            Text(truncatedTitle(title))
                .font(.title5)
                .foregroundColor(titleColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: Metrics.contentHeight)
                .padding(.horizontal, 48) // 좌우 버튼과의 간섭 방지용 여유
                .allowsHitTesting(false)
        }
        .frame(height: Metrics.totalHeight)
        .background(background)
    }

    // MARK: - Buttons

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: Metrics.iconSize, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: Metrics.tappableSize, height: Metrics.tappableSize)
        }
        .buttonStyle(.plain)
        .glassEffect()
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Image(systemName: "gearshape")
                .font(.system(size: Metrics.iconSize, weight: .semibold))
                .foregroundColor(rightIconColor)
                .frame(width: Metrics.tappableSize, height: Metrics.tappableSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect()
    }

    // MARK: - Helpers

    // 최대 8자 초과 시 말줄임을 명시적으로 유도 (실제 표시 줄임은 lineLimit + truncationMode로 처리)
    private func truncatedTitle(_ text: String) -> String {
        guard text.count > 10 else { return text }
        let prefix = text.prefix(10)
        return String(prefix)
    }
}

#Preview {
    VStack(spacing: 0) {
        ProfileDetailNavigationBar(
            title: "애플코리아",
            onBack: { },
            onEdit: { }
        )
        .background(Color("Background"))

        ProfileDetailNavigationBar(
            title: "아주아주아주아주아주아긴",
            onBack: { },
            onEdit: { }
        )
        .background(Color("Background"))
    }
}
