import SwiftUI

/// Contacts 전용 상단 타이틀바
struct ContactsTopBar: View {
    var title: String = "Contacts"
    var onPlus: () -> Void

    // Style tokens
    private let height: CGFloat = 44 // 실제 컨텐츠 높이는 44, 상하 패딩 8을 더해 전체 영역 60
    private let verticalPadding: CGFloat = 8
    private let horizontalPadding: CGFloat = 16

    // Colors (확정된 Asset 이름 사용)
    private var backgroundColor: Color { Color("Background") }
    private var separatorColor: Color { Color("BackgroundDisabled") }
    private var titleColor: Color { Color("Dark") }
    private var plusNormalColor: Color { Color("Primary") }
    private var plusPressedColor: Color { Color("PrimaryHover") }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Left spacer (좌측 버튼 없음)
                Spacer(minLength: 0)

                // Center title
                Text(title)
                    .font(.title1) // Pretendard Semibold 24pt (Font+Ex 매핑)
                    .foregroundColor(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Right + button (애플 기본 머티리얼 기반 원형)
                PlusButton(
                    normalColor: plusNormalColor,
                    pressedColor: plusPressedColor,
                    action: onPlus
                )
            }
            .frame(height: height)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)

            Rectangle()
                .fill(separatorColor)
                .frame(height: 0)
        }
    }
}

// MARK: - Internal + Button (원형 머티리얼 + pressed 색상 반영)
private struct PlusButton: View {
    let normalColor: Color
    let pressedColor: Color
    let action: () -> Void

    @State private var isPressed: Bool = false
    private let size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            ZStack {
                // 원형 머티리얼 배경 (애플 기본)
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)

                // 아이콘
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isPressed ? pressedColor : normalColor)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect()
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = false }
                }
        )
        .accessibilityLabel(Text("추가"))
    }
}

#Preview {
    ContactsTopBar { }
}
