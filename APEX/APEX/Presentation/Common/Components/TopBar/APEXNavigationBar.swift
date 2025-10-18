//
//  APEXNavigationBar.swift
//  APEX
//
//  Created by AI Assistant on 10/18/25.
//

import SwiftUI

/// Common top navigation bar used across screens
struct APEXNavigationBar: View {
    enum Kind {
        /// 1) Plain: back button only
        case plain(onBack: () -> Void)
        /// 2) Memo: back (left), title (center), search + hamburger (right)
        case memo(title: String, onBack: () -> Void, onSearch: () -> Void, onMenu: () -> Void)
    }

    private let kind: Kind

    // Theme
    private var background: Color = Color("Background")
    private var separator: Color = Color("BackgoundDisabled")
    private var foreground: Color = .black
    private var height: CGFloat = 52

    init(_ kind: Kind) {
        self.kind = kind
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                // Left/Right lane
                HStack(spacing: 0) {
                    left
                    Spacer(minLength: 0)
                    right
                }
                .frame(height: height)
                .padding(.horizontal, 12)
                .background(background)

                // Center title overlay (kept independent from side widths)
                center
                    .frame(height: height)
                    .padding(.horizontal, 12)
                    .allowsHitTesting(false)
            }

            Rectangle()
                .fill(separator)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var left: some View {
        switch kind {
        case .plain(let onBack):
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title4)
                    .foregroundColor(foreground)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .memo(_, let onBack, _, _):
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title4)
                    .foregroundColor(foreground)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect()
        }
    }

    @ViewBuilder
    private var center: some View {
        switch kind {
        case .plain:
            EmptyView()
        case .memo(let title, _, _, _):
            Text(title)
                .font(.title3)
                .foregroundColor(foreground)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var right: some View {
        switch kind {
        case .plain:
            Color.clear.frame(width: 44, height: 44)
        case .memo(_, _, let onSearch, let onMenu):
            HStack(spacing: 4) {
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.title4)
                        .foregroundColor(foreground)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()

                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title4)
                        .foregroundColor(foreground)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        APEXNavigationBar(.plain(onBack: { }))

        APEXNavigationBar(
            .memo(
                title: "Gyeong",
                onBack: { },
                onSearch: { },
                onMenu: { }
            )
        )
    }
}
