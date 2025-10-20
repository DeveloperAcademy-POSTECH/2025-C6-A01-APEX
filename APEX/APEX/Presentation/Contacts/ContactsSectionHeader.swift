import SwiftUI

/// 섹션 제목 + 카운트 + 접힘/펼침 토글
struct ContactsSectionHeader: View {
    let title: String
    let countText: String?
    @Binding var isExpanded: Bool

    private let horizontalPadding: CGFloat = 16

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(composedTitle)
                    .font(.body5)
                    .foregroundColor(.primary)
                Spacer(minLength: 8)
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, horizontalPadding)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    private var composedTitle: String {
        if let countText, !countText.isEmpty {
            return "\(title) \(countText)"
        }
        return title
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
