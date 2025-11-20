import SwiftUI

struct MediaGrid: View {
    let images: [ImageAttachment]
    let videos: [VideoAttachment]
    var onOpen: (_ isImage: Bool, _ localIndex: Int) -> Void
    var onShareImageAt: (_ index: Int) -> Void
    var onShareVideoAt: (_ index: Int) -> Void
    var onDeleteImageAt: (_ index: Int) -> Void
    var onDeleteVideoAt: (_ index: Int) -> Void
    var onShareAll: () -> Void
    var onDeleteMemo: () -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    private enum Metrics {
        static let tileSize: CGFloat = 106
        static let spacing: CGFloat = 1
        static let cornerRadius: CGFloat = 2
    }

    var body: some View {
        struct CombinedItem { let isImage: Bool; let index: Int; let order: Int }
        let merged: [CombinedItem] = {
            var combined: [CombinedItem] = []
            for (imageIndex, img) in images.enumerated() {
                let order = img.orderIndex ?? imageIndex
                combined.append(CombinedItem(isImage: true, index: imageIndex, order: order))
            }
            for (videoIndex, vid) in videos.enumerated() {
                let order = vid.orderIndex ?? (images.count + videoIndex)
                combined.append(CombinedItem(isImage: false, index: videoIndex, order: order))
            }
            return combined.sorted { $0.order < $1.order }
        }()

        let fullCount = (merged.count / 3) * 3
        let head = Array(merged.prefix(fullCount))
        let tail = Array(merged.suffix(merged.count - fullCount))

        return VStack(spacing: Metrics.spacing) {
            if !head.isEmpty {
                let headRowCount = head.count / 3
                let forceRTLAllRows = (merged.count == 2 || merged.count == 3)
                let orderedHead: [CombinedItem] = (0..<headRowCount).flatMap { rowIndex -> [CombinedItem] in
                    let start = rowIndex * 3
                    let end = start + 3
                    let rowItems = Array(head[start..<end])
                    let isLastOverallRow = tail.isEmpty && (rowIndex == headRowCount - 1)
                    if forceRTLAllRows { return rowItems.reversed() }
                    return isLastOverallRow ? rowItems : rowItems.reversed()
                }
                LazyVGrid(columns: columns, spacing: Metrics.spacing) {
                    ForEach(orderedHead.indices, id: \.self) { idx in
                        let item = orderedHead[idx]
                        if item.isImage {
                            let img = images[item.index]
                            APEXMediaTile(source: .image(img.data))
                                .frame(width: Metrics.tileSize, height: Metrics.tileSize)
                                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                .overlay {
                                    if let progress = img.progress {
                                        ProgressOverlay(progress: progress)
                                            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { onOpen(true, item.index) }
                        } else {
                            let video = videos[item.index]
                            APEXMediaTile(source: .video(video.url), showVideoIcon: true, variant: .grid, showsDuration: false)
                                .frame(width: Metrics.tileSize, height: Metrics.tileSize)
                                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                .overlay {
                                    if let progress = video.progress {
                                        ProgressOverlay(progress: progress)
                                            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                    }
                                }
                                .overlay(alignment: .bottomLeading) {
                                    Text(format(durationOf: video.url))
                                        .font(.caption1)
                                        .foregroundStyle(.white)
                                        .padding(12)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { onOpen(false, item.index) }
                        }
                    }
                }
            }

            if !tail.isEmpty {
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let spacing = Metrics.spacing
                    if tail.count == 1 {
                        let item = tail[0]
                        HStack(spacing: 0) {
                            if item.isImage {
                                let img = images[item.index]
                                APEXMediaTile(source: .image(img.data))
                                    .frame(width: totalWidth, height: Metrics.tileSize)
                                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                    .overlay {
                                        if let progress = img.progress {
                                            ProgressOverlay(progress: progress)
                                                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { onOpen(true, item.index) }
                            } else {
                                let video = videos[item.index]
                                APEXMediaTile(source: .video(video.url), showVideoIcon: true, variant: .grid, showsDuration: false)
                                    .frame(width: totalWidth, height: Metrics.tileSize)
                                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                    .overlay {
                                        if let progress = video.progress {
                                            ProgressOverlay(progress: progress)
                                                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                        }
                                    }
                                    .overlay(alignment: .bottomLeading) {
                                        Text(format(durationOf: video.url))
                                            .font(.caption1)
                                            .foregroundStyle(.white)
                                            .padding(12)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { onOpen(false, item.index) }
                            }
                        }
                    } else if tail.count == 2 {
                        let width = (merged.count == 2) ? Metrics.tileSize : (totalWidth - spacing) / 2
                        HStack(spacing: spacing) {
                            ForEach((merged.count == 2 ? Array(tail.indices.reversed()) : Array(tail.indices)), id: \.self) { j in
                                let item = tail[j]
                                if item.isImage {
                                    let img = images[item.index]
                                    APEXMediaTile(source: .image(img.data))
                                        .frame(width: width, height: Metrics.tileSize)
                                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                        .overlay {
                                            if let progress = img.progress {
                                                ProgressOverlay(progress: progress)
                                                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture { onOpen(true, item.index) }
                                } else {
                                    let video = videos[item.index]
                                    APEXMediaTile(source: .video(video.url), showVideoIcon: true, variant: .grid, showsDuration: false)
                                        .frame(width: width, height: Metrics.tileSize)
                                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                        .overlay {
                                            if let progress = video.progress {
                                                ProgressOverlay(progress: progress)
                                                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                            }
                                        }
                                        .overlay(alignment: .bottomLeading) {
                                            Text(format(durationOf: video.url))
                                                .font(.caption1)
                                                .foregroundStyle(.white)
                                                .padding(12)
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture { onOpen(false, item.index) }
                                }
                            }
                        }
                    }
                }
                .frame(width: (merged.count == 2) ? (Metrics.tileSize * 2 + Metrics.spacing) : (Metrics.tileSize * 3 + Metrics.spacing * 2), height: Metrics.tileSize)
            }
        }
    }
}


