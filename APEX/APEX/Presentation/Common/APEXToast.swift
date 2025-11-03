import SwiftUI

// MARK: - Simple Toast (Image + Text + Button)

struct APEXToast: View {
    var image: Image?
    var text: String
    var buttonTitle: String?   // when nil, no right button
    var onButtonTap: (() -> Void)?

    // Minimal style tokens aligned with project
    var background: Color = .black.opacity(0.9)
    var iconTint: Color = Color("Background")

    var body: some View {
        let hasButton = (buttonTitle != nil && onButtonTap != nil)

        return ZStack {
            // Base layout keeps sizing consistent
            HStack {
                // Show leading icon only when button exists; otherwise, we'll render it in the centered overlay
                if let image, hasButton {
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
                    .opacity(hasButton ? 1 : 0) // hide when centering via overlay

                if hasButton, let title = buttonTitle {
                    Button(title) { onButtonTap?() }
                        .font(.body5)
                        .foregroundColor(Color("Background"))
                        .buttonStyle(.plain)
                }
            }
            // Centered label (with icon) when no button
            if !hasButton {
                HStack(spacing: 8) {
                    if let image {
                        image
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(iconTint)
                            .imageScale(.medium)
                    }
                    Text(text)
                        .font(.body4)
                        .foregroundColor(Color("Background"))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
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
    let buttonTitle: String?
    let onButtonTap: (() -> Void)?
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
                            onButtonTap?()
                            withAnimation(.easeInOut(duration: 0.35)) {
                                isPresented = false
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(1000)
                .allowsHitTesting(true)  // 버튼을 클릭할 수 있도록 true로 변경
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
        buttonTitle: String? = nil,
        duration: TimeInterval = 2.0,
        onButtonTap: (() -> Void)? = nil
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
                duration: 2.0
            )
        }
    }
    return PreviewContainer()
}
