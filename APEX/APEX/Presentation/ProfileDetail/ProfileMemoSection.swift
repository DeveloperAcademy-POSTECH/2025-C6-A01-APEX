import SwiftUI

/// 메모 입력 섹션: 라벨, TextEditor, 글자 수 카운트
/// 나중에 필요: 저장 정책, 최대 글자수 제한/경고
struct ProfileMemoSection: View {
    @Binding var text: String
    var characterLimit: Int? = nil

    private let corner: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("메모")
                .font(.body6)
                .foregroundColor(.gray)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body2)
                    .frame(minHeight: 120)
                    .padding(8)

                if text.isEmpty {
                    Text("메모를 입력하세요")
                        .font(.body2)
                        .foregroundColor(Color("BackgoundDisabled"))
                        .padding(.top, 14)
                        .padding(.leading, 12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .inset(by: 0.5)
                    .stroke(Color("BackgoundDisabled"), lineWidth: 1)
            }

            if let limit = characterLimit {
                HStack {
                    Spacer()
                    Text("\(text.count)/\(limit)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

#Preview {
    struct P: View {
        @State var memo = ""
        var body: some View {
            ProfileMemoSection(text: $memo, characterLimit: 100)
        }
    }
    return P()
}
