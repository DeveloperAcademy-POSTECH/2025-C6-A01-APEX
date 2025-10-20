import SwiftUI

/// 섹션 제목 + 카운트(포함 프로필 개수) + 접힘/펼침 토글
struct ContactsSectionHeader: View {
    let title: String
    /// 제목 옆에 붙는 개수 텍스트(예: "4") — 포함된 프로필 개수
    let countText: String?
    @Binding var isExpanded: Bool

    // Style tokens
    private let horizontalPadding: CGFloat = 16
    private let height: CGFloat = 44

    // Design tokens
    // 시스템 회색 사용으로 변경
    private var labelGray: Color { .secondary }

    // Press feedback
    @State private var pressed: Bool = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.1)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(composedTitle)
                    .font(.body1) // Pretendard Semibold 16
                    .foregroundColor(labelGray)
                    .lineLimit(1)
                    .accessibilityLabel(Text(accessibilityTitle))

                Spacer(minLength: 8)

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.body1)
                    .foregroundColor(labelGray)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .accessibilityAddTraits(.isHeader)
    }

    private var composedTitle: String {
        if let countText, !countText.isEmpty {
            return "\(title) \(countText)"
        }
        return title
    }

    private var accessibilityTitle: String {
        if let countText, !countText.isEmpty {
            return "\(title), \(countText) items, \(isExpanded ? "expanded" : "collapsed")"
        }
        return "\(title), \(isExpanded ? "expanded" : "collapsed")"
    }
}

#Preview {
    StatefulPreviewWrapper(false) { isExpanded in
        ContactsSectionHeader(title: "Favorites", countText: "4", isExpanded: isExpanded)
    }
}

// 미리보기용 작은 유틸
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content

    init(_ value: Value, content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }

    var body: some View { content($value) }
}
