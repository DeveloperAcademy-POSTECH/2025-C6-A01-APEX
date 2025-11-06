//
//  MediaHeaderBar.swift
//  APEX
//
//  Created by 조운경 on 10/28/25.
//

import SwiftUI

struct MediaHeaderBar: View {
    let title: String
    let uploadedAt: Date?
    var onBack: () -> Void
    var onGrid: () -> Void
    var onTitleTap: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            .ignoresSafeArea(edges: .top)

            HStack(alignment: .center) {
                Button(action: { onBack() }, label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        
                })
                .buttonStyle(.plain)
                .glassEffect()

                Spacer()
                
                Button(action: { onTitleTap() }) {
                    VStack(alignment: .center, spacing: 2) {
                        Text(title)
                            .font(.title5)
                        if let uploadedAt {
                            HStack(alignment: .center, spacing: 4) {
                                Text(uploadedAt.formattedHeaderDate)
                                    .font(.caption3)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                    }
                }
                .glassEffect()
                .buttonStyle(.plain)
                
                Spacer()

                Button(action: { onGrid() }, label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                })
                .buttonStyle(.plain).glassEffect()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            MediaHeaderBar(title: "Gyeong", uploadedAt: Date(), onBack: {}, onGrid: {}, onTitleTap:  {})
            Spacer()
        }
    }
}
