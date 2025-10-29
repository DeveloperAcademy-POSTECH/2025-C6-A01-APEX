//
//  MediaPlaybackBar.swift
//  APEX
//
//  Created by APEX Assistant on 10/28/25.
//

import SwiftUI

struct MediaPlaybackBar: View {
    @Binding var current: Double
    @Binding var total: Double
    @Binding var volume: Double
    var onScrub: (Double) -> Void
    var onScrubBegan: () -> Void = {}
    var onScrubEnded: () -> Void = {}

    private func formatClock(_ seconds: Double) -> String {
        let rounded = Int(seconds.rounded())
        let minutes = rounded / 60
        let secs = rounded % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(formatClock(current))
                .font(.caption2)
                .foregroundStyle(.white)

            ProgressSeekBar(
                current: $current,
                total: $total,
                onScrub: onScrub,
                onScrubBegan: onScrubBegan,
                onScrubEnded: onScrubEnded
            )
            .frame(height: 4)
            .padding(.bottom, 6)

            Text(formatClock(total))
                .font(.caption2)
                .foregroundStyle(.white)

            Button(action: { volume = (volume == 0) ? 1.0 : 0.0 }, label: {
                Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(Color("Primary"))
                    .font(.system(size: 15, weight: .medium))
            })
            .accessibilityLabel(Text(volume == 0 ? "소리 켜기" : "음소거"))
        }
        .frame(height: 44)
    }
}
private struct ProgressSeekBar: View {
    @Binding var current: Double
    @Binding var total: Double
    var onScrub: (Double) -> Void
    var onScrubBegan: () -> Void = {}
    var onScrubEnded: () -> Void = {}

    @GestureState private var isDragging: Bool = false

    private func progress() -> Double { total > 0 ? max(0, min(current / total, 1)) : 0 }

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let height = max(4, geo.size.height)
            let pct = progress()
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: height)
                Capsule()
                    .fill(Color("Primary"))
                    .frame(width: width * CGFloat(pct), height: height)
                Circle()
                    .fill(Color("Primary"))
                    .frame(width: height + 6.0, height: height + 6.0)
                    .offset(
                        x: max(
                            0,
                            min(
                                width - (height + 6.0),
                                (width * CGFloat(pct)) - (height + 6.0) / 2.0
                            )
                        )
                    )
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        if state == false { onScrubBegan() }
                        state = true
                    }
                    .onChanged { value in
                        let clampedX = max(0, min(width, value.location.x))
                        let ratio = Double(clampedX) / Double(width)
                        let newSeconds = (total > 0) ? (ratio * total) : 0
                        current = newSeconds
                        onScrub(newSeconds)
                    }
                    .onEnded { _ in
                        onScrubEnded()
                    }
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MediaPlaybackBar(
            current: .constant(35),
            total: .constant(120),
            volume: .constant(0.8),
            onScrub: { _ in }
        )
        .padding()
    }
}

