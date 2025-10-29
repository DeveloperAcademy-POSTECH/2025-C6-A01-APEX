//
//  MediaBottomBar.swift
//  APEX
//
//  Created by 조운경 on 10/28/25.
//

import SwiftUI

struct MediaBottomBar: View {
    let index: Int
    let total: Int

    var onShare: () -> Void
    var onSave: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 98)
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 12) {
                // Page indicator removed per design request

                // Action buttons row
                HStack(spacing: 48) {
                    Spacer(minLength: 0)
                    actionButton(systemName: "square.and.arrow.down", accessibility: "저장", action: onSave)
                    actionButton(systemName: "square.and.arrow.up", accessibility: "공유", action: onShare)
                    actionButton(systemName: "trash", accessibility: "삭제", action: onDelete)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
            }
            .padding(.bottom, 16)
        }
        .allowsHitTesting(true)
    }

    private func actionButton(systemName: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .glassEffect()
        }
        .accessibilityLabel(Text(accessibility))
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            MediaBottomBar(
                index: 0,
                total: 5,
                onShare: {},
                onSave: {},
                onDelete: {}
            )
        }
    }
}
