//
//  APEXShareTopBar.swift
//  APEX
//
//  Created by AI Assistant on 10/29/25.
//

import SwiftUI

/// Top bar for ShareView: left close, centered title, right Share with count badge
struct APEXShareTopBar: View {
    let title: String
    let selectedCount: Int
    let onClose: () -> Void
    let onSearch: () -> Void

    // Theme tokens (match existing top bars)
    private var background: Color = Color("Background")
    private var foreground: Color = .black
    private var height: CGFloat = 52

    init(
        title: String,
        selectedCount: Int,
        onClose: @escaping () -> Void,
        onSearch: @escaping () -> Void
    ) {
        self.title = title
        self.selectedCount = selectedCount
        self.onClose = onClose
        self.onSearch = onSearch
    }

    var body: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                leftButton
                Spacer(minLength: 0)
                rightButton
            }
            .frame(height: height)
            .padding(.horizontal, 12)
            VStack(spacing: 0) {
                Text(title)
                    .lineLimit(1)
                    .font(.title5)
                    .foregroundColor(foreground)
                if selectedCount > 0 {
                    Text("\(selectedCount)명")
                        .lineLimit(1)
                        .font(.caption2)
                        .foregroundColor(Color("Primary"))
                }
            }
            .frame(height: height)
            .padding(.horizontal, 12)
            .allowsHitTesting(false)
        }
        .padding(.vertical, 8)
        .background(.white)
    }

    private var leftButton: some View {
        Button(action: onClose) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(foreground)
                .frame(width: 44, height: 44)
                .glassEffect()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("닫기"))
    }

    private var rightButton: some View {
        Button(action: onSearch) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(foreground)
                .frame(width: 44, height: 44)
                .glassEffect()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("검색"))
    }
}

// (no extra styles needed for simple icon button)

#Preview {
    VStack(spacing: 0) {
        APEXShareTopBar(title: "Share", selectedCount: 4, onClose: { }, onSearch: { })
    }
}

// MARK: - Record Top Bar (Close + Done)

struct APEXRecordTopBar: View {
    let onClose: () -> Void
    let onDone: () -> Void

    private var background: Color = Color("Background")
    private var foreground: Color = .black
    private var height: CGFloat = 52

    init(onClose: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.onClose = onClose
        self.onDone = onDone
    }

    var body: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.title4)
                        .foregroundColor(foreground)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()

                Spacer(minLength: 0)

                Button(action: onDone) {
                    Text("완료")
                        .font(.callout)
                        .foregroundColor(foreground)
                        .frame(height: 44)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()
            }
            .frame(height: height)
            .padding(.horizontal, 12)
            .background(background)
        }
    }
}

