import SwiftUI

struct ChatSearchBar: View {
    @Binding var text: String
    @FocusState var isFocused: Bool
    var onPrev: () -> Void
    var onNext: () -> Void
    var onClose: () -> Void
    var onTextChange: (String) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onPrev) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 17, weight: .regular))
                        .frame(width: 22, height: 36)
                        
                }
                .buttonStyle(.plain)
                
                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .regular))
                        .frame(width: 22, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .glassEffect(in: Capsule())

            TextField("노트 내용 검색", text: $text)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onChange(of: text) { _, newValue in
                    onTextChange(newValue)
                }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .glassEffect(in: Capsule())

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .glassEffect()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 20)
    }
}

#Preview {
    ChatSearchBar(text: .constant("메모"), onPrev: { }, onNext: { }, onClose: { }, onTextChange: { _ in })
}
