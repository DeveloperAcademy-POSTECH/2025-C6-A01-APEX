//
//  AttachBar.swift
//  APEX
//
//  Created by AI Assistant on 10/29/25.
//

import SwiftUI

struct ShareAttachmentItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case image(UIImage)
        case video(URL?, thumbnail: UIImage?)
        case file(URL)
        case text(String)
        case audio(URL)
    }
    let id: UUID
    var kind: Kind
}

struct AttachBar: View {
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
                // Only show visual media (image/video) in the attach bar
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
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .contentShape(Rectangle())
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
        case .file:
            // Non-visual in AttachBar (hidden via filter above)
            Color.clear
        case .text:
            // Non-visual in AttachBar (hidden via filter above)
            Color.clear
        case .audio:
            // Non-visual in AttachBar (hidden via filter above)
            Color.clear
        }
    }
}

#Preview {
    let sample = [
        ShareAttachmentItem(id: UUID(), kind: .image(UIImage(systemName: "person.crop.circle")!)),
        ShareAttachmentItem(id: UUID(), kind: .video(nil, thumbnail: nil))
    ]
    return AttachBar(items: sample, onRemove: { _ in })
}
