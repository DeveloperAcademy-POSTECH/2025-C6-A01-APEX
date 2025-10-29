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
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .glassEffect()
                })

                Spacer()
                
                Button {
                    
                } label: {
                    VStack(alignment: .center, spacing: 2) {
                        Text(title)
                            .font(.title5)
                            .foregroundStyle(.white)
                        if let uploadedAt {
                            Text(uploadedAt.formattedHeaderDate)
                                .font(.caption3)
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                Spacer()

                Button(action: { onGrid() }, label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .glassEffect()
                })
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
            MediaHeaderBar(title: "Gyeong", uploadedAt: Date(), onBack: {}, onGrid: {})
            Spacer()
        }
    }
}
