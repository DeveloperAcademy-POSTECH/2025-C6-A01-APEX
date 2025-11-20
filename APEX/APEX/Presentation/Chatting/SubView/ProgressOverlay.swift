import SwiftUI

struct ProgressOverlay: View {
    let progress: Double // 0...1
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
        }
    }
}


