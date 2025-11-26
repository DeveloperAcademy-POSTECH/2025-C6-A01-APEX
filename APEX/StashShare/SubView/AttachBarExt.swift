//
//  AttachBarExt.swift
//  StashShare
//
//  Extracted from ShareSheetView for reuse and organization.
//

import SwiftUI

struct AttachBarExt: View {
    let items: [ShareAttachmentItem]
    var onRemove: (ShareAttachmentItem) -> Void
    
    private enum Metrics {
        static let itemSize: CGFloat = 72
        static let corner: CGFloat = 3.95
        static let spacing: CGFloat = 8
        static let xSize: CGFloat = 16
        static let xTapSize: CGFloat = 28
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Metrics.spacing) {
                ForEach(items.filter { item in
                    switch item.kind {
                    case .image, .video:
                        return true
                    default:
                        return false
                    }
                }) { item in
                    itemView(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func itemView(_ item: ShareAttachmentItem) -> some View {
        ZStack(alignment: .topTrailing) {
            content(for: item)
                .frame(width: Metrics.itemSize, height: Metrics.itemSize)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
            
            Button {
                onRemove(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Metrics.xSize, weight: .medium))
                    .foregroundColor(.gray)
                    .background(Color.white)
                    .clipShape(Circle()) // Clip the image to a circle
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .frame(width: Metrics.xTapSize, height: Metrics.xTapSize, alignment: .topTrailing)
        }
        .background(Color("BackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
    }
    
    @ViewBuilder
    private func content(for item: ShareAttachmentItem) -> some View {
        switch item.kind {
        case .image(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        case .video(_, let thumbnail):
            ZStack {
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Color("BackgroundSecondary"))
                }
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(radius: 2)
            }
        default:
            Color.clear
        }
    }
}


