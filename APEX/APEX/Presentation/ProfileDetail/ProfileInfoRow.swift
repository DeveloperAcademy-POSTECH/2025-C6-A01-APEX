import SwiftUI

/// 아이콘 + 라벨 + 값 + 액션(탭/복사) 행
/// 나중에 필요: 길게 눌러 복사, 우측 보조 버튼(복사/공유) 배치
struct ProfileInfoRow: View {
    let icon: Image
    let title: String
    let value: String
    var action: (() -> Void)? = nil
    var onCopy: (() -> Void)? = nil

    private enum Metrics {
        static let vSpacing: CGFloat = 6
        static let hSpacing: CGFloat = 12
        static let lineHeight: CGFloat = 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.vSpacing) {
            Text(title)
                .font(.body6)
                .foregroundColor(.gray)

            Button {
                action?()
            } label: {
                HStack(spacing: Metrics.hSpacing) {
                    icon
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)

                    Text(value)
                        .font(.body2)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 8)

                    if let onCopy {
                        Button(action: onCopy) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color("Primary"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color("BackgoundDisabled"))
                .frame(height: Metrics.lineHeight)
        }
    }
}

#Preview {
    ProfileInfoRow(
        icon: Image(systemName: "envelope"),
        title: "이메일",
        value: "karynkim@postech.ac.kr",
        action: { },
        onCopy: { }
    )
}
