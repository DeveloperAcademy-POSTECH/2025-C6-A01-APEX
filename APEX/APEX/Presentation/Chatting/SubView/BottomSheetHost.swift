import SwiftUI
import UIKit

struct BottomSheetHost<Content: View>: View {
    @Binding var mode: ChattingView.BottomSheetMode
    var onHeightChanged: (CGFloat, ChattingView.BottomSheetMode) -> Void = { _, _ in }
    var cornerRadius: CGFloat = 16
    var content: () -> Content

    @GestureState private var dragY: CGFloat = 0

    private var bottomInset: CGFloat {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let win = scene.windows.first(where: { $0.isKeyWindow }) {
            return win.safeAreaInsets.bottom
        }
        return 0
    }
    private var screenH: CGFloat { UIScreen.main.bounds.height - bottomInset }

    private var collapsedHeight: CGFloat { screenH * 0.4 }
    private var expandedHeight: CGFloat { screenH * 0.85 }
    private var targetHeight: CGFloat {
        switch mode {
        case .hidden: return 0
        case .collapsed: return collapsedHeight
        case .expanded: return expandedHeight
        }
    }

    var body: some View {
        let threshold: CGFloat = 60
        let drag = DragGesture()
            .updating($dragY) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                switch mode {
                case .collapsed:
                    let base = collapsedHeight
                    let offset = -value.translation.height * 0.9
                    let endHeight = min(max(base + offset, 0), expandedHeight)
                    let towardExpanded = (value.predictedEndTranslation.height < -threshold) || (endHeight > (collapsedHeight + expandedHeight) / 2)
                    let towardHidden = (value.predictedEndTranslation.height > threshold) || (endHeight < collapsedHeight * 0.45)
                    if towardExpanded {
                        mode = .expanded
                    } else if towardHidden {
                        mode = .hidden
                    } else {
                        mode = .collapsed
                    }
                case .expanded:
                    let base = expandedHeight
                    let offset = -max(0, value.translation.height) * 1.0
                    let endHeight = min(max(base + offset, collapsedHeight), expandedHeight)
                    let towardCollapsed = (value.predictedEndTranslation.height > threshold) || (endHeight < (collapsedHeight + expandedHeight) / 2)
                    mode = towardCollapsed ? .collapsed : .expanded
                case .hidden:
                    break
                }
            }

        let interactiveOffset: CGFloat = {
            switch mode {
            case .collapsed:
                let upward = min(0, dragY)
                let downward = max(0, dragY)
                if downward > 0 {
                    return -downward * 0.9
                } else {
                    return -upward * 0.9
                }
            case .expanded:
                let allowed = max(0, dragY)
                return -allowed * 1.0
            case .hidden:
                return 0
            }
        }()
        let baseHeight = targetHeight
        let unclampedHeight = baseHeight + interactiveOffset
        let displayedHeight: CGFloat = {
            switch mode {
            case .collapsed:
                return min(max(unclampedHeight, 0), expandedHeight)
            case .expanded:
                return min(max(unclampedHeight, collapsedHeight), expandedHeight)
            case .hidden:
                return 0
            }
        }()

        VStack(spacing: 0) {
            if mode != .expanded {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }

            content()
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(0, displayedHeight))
        .background(Color("Background"))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.92), value: mode)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.9), value: dragY)
        .gesture(drag)
        .onChange(of: mode) { _, newMode in
            let calculatedHeight: CGFloat
            switch newMode {
            case .hidden: calculatedHeight = 0
            case .collapsed: calculatedHeight = collapsedHeight
            case .expanded: calculatedHeight = expandedHeight
            }
            onHeightChanged(calculatedHeight, newMode)
        }
        .onChange(of: dragY) { _, _ in
            onHeightChanged(displayedHeight, mode)
        }
        .onAppear {
            let calculatedHeight: CGFloat
            switch mode {
            case .hidden: calculatedHeight = 0
            case .collapsed: calculatedHeight = collapsedHeight
            case .expanded: calculatedHeight = expandedHeight
            }
            onHeightChanged(calculatedHeight, mode)
        }
    }
}


