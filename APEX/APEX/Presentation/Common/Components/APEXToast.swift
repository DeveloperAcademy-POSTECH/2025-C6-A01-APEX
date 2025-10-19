import SwiftUI

// MARK: - Simple Toast (Image + Text + Button)

struct APEXToast: View {
    var image: Image?
    var text: String
    var buttonTitle: String = "확인"
    var onButtonTap: () -> Void

    // Minimal style tokens aligned with project
    var background: Color = .black.opacity(0.9)
    var iconTint: Color = Color("Background")

    var body: some View {
        HStack {
            if let image {
                image
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconTint)
                    .imageScale(.medium)
                    .padding(.trailing, 8)
            }

            Text(text)
                .font(.body4)
                .foregroundColor(Color("Background"))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(buttonTitle, action: onButtonTap)
                .font(.body5)
                .foregroundColor(Color("Background"))
                .buttonStyle(.plain)
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Overlay Presenter (bottom)

private struct APEXToastOverlay: ViewModifier {
    @Binding var isPresented: Bool
    let image: Image?
    let text: String
    let buttonTitle: String
    let onButtonTap: () -> Void
    let duration: TimeInterval

    @State private var hideWorkItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                VStack {
                    Spacer()
                    APEXToast(
                        image: image,
                        text: text,
                        buttonTitle: buttonTitle,
                        onButtonTap: {
                            hideWorkItem?.cancel()
                            onButtonTap()
                            withAnimation(.easeInOut(duration: 0.35)) {
                                isPresented = false
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isPresented)
        .onChange(of: isPresented) { newValue in
            if newValue { scheduleAutoHide() } else { cancelAutoHide() }
        }
        .onAppear {
            if isPresented { scheduleAutoHide() }
        }
    }

    private func scheduleAutoHide() {
        cancelAutoHide()
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.35)) { isPresented = false }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func cancelAutoHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }
}

extension View {
    func apexToast(
        isPresented: Binding<Bool>,
        image: Image? = Image(systemName: "info.circle.fill"),
        text: String,
        buttonTitle: String = "확인",
        duration: TimeInterval = 2.0,
        onButtonTap: @escaping () -> Void
    ) -> some View {
        modifier(
            APEXToastOverlay(
                isPresented: isPresented,
                image: image,
                text: text,
                buttonTitle: buttonTitle,
                onButtonTap: onButtonTap,
                duration: duration
            )
        )
    }
}

#Preview {
    struct PreviewContainer: View {
        @State private var show = false

        var body: some View {
            VStack(spacing: 16) {
                APEXButton("토스트 표시") { show = true }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("Background"))
            .apexToast(
                isPresented: $show,
                image: Image(systemName: "star.slash"),
                text: "즐겨찾기를 해제했습니다.",
                buttonTitle: "되돌리기",
                duration: 2.0
            ) {
                print("되돌리기")
            }
        }
    }
    return PreviewContainer()
}
