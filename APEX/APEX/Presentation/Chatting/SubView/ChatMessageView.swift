import SwiftUI
import UIKit

struct ChatMessageView: View {
    let note: Note
    let chatTitle: String
    let currentClientId: UUID
    let highlightQuery: String?
    let leadingReservedWidth: CGFloat
    struct ChatAnchor { let noteId: UUID; let isImage: Bool; let localIndex: Int }
    let buildViewerPayload: (ChatAnchor) -> (items: [MediaSource], anchors: [ChatAnchor], index: Int)
    let onOpenViewer: (ChatAnchor) -> Void
    let onOpenShare: (String) -> Void
    let onOpenShareFiles: ([URL]) -> Void
    let onOpenShareAudio: (URL) -> Void
    let onDeleteFile: (UUID, Int) -> Void
    let onOpenRecord: (URL) -> Void
    let onDelete: (ChatAnchor) -> Void
    let onDeleteAudio: (UUID, URL) -> Void
    let onCopyText: (String) -> Void
    let onStartEdit: (UUID, String) -> Void
    let onStartMultiDelete: (UUID) -> Void
    @State private var showDeleteAlert: Bool = false
    @State private var deleteSubjectText: String = ""
    @State private var pendingDelete: (() -> Void)?
    
    private enum Metrics {
        static let tileSize: CGFloat = 106
        static let spacing: CGFloat = 1
        static let cornerRadius: CGFloat = 15
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if case let .media(images, videos) = note.bundle {
                if videos.count == 1, images.isEmpty {
                    APEXMediaSingleCard(
                        source: .video(videos[0].url),
                        baseTileWidth: Metrics.tileSize,
                        columnsSpanned: 2,
                        spacing: Metrics.spacing,
                        cornerRadius: Metrics.cornerRadius
                    )
                    .onTapGesture {
                        onOpenViewer(ChatAnchor(noteId: note.id, isImage: false, localIndex: 0))
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            onOpenShareFiles([videos[0].url])
                        } label: {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .tint(.primary)
                        Button(role: .destructive) {
                            onStartMultiDelete(note.id)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                } else if images.count == 1, videos.isEmpty {
                    APEXMediaSingleCard(
                        source: .image(images[0].data),
                        baseTileWidth: Metrics.tileSize,
                        columnsSpanned: 2,
                        spacing: Metrics.spacing,
                        cornerRadius: Metrics.cornerRadius
                    )
                    .onTapGesture {
                        onOpenViewer(ChatAnchor(noteId: note.id, isImage: true, localIndex: 0))
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            if let url = tempURLForImageData(images[0].data) {
                                onOpenShareFiles([url])
                            }
                        } label: {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .tint(.primary)
                        Button(role: .destructive) {
                            onStartMultiDelete(note.id)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                } else {
                    MediaGrid(
                        images: images,
                        videos: videos,
                        onOpen: { isImage, localIndex in
                            onOpenViewer(ChatAnchor(noteId: note.id, isImage: isImage, localIndex: localIndex))
                        },
                        onShareImageAt: { _ in },
                        onShareVideoAt: { _ in },
                        onDeleteImageAt: { _ in },
                        onDeleteVideoAt: { _ in },
                        onShareAll: {
                            var urls: [URL] = []
                            for img in images {
                                if let url = tempURLForImageData(img.data) { urls.append(url) }
                            }
                            urls.append(contentsOf: videos.map { $0.url })
                            if !urls.isEmpty { onOpenShareFiles(urls) }
                        },
                        onDeleteMemo: {
                            onStartMultiDelete(note.id)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            var urls: [URL] = []
                            for img in images {
                                if let url = tempURLForImageData(img.data) { urls.append(url) }
                            }
                            urls.append(contentsOf: videos.map { $0.url })
                            if !urls.isEmpty { onOpenShareFiles(urls) }
                        } label: {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .tint(.primary)
                        Button(role: .destructive) {
                            onStartMultiDelete(note.id)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            } else if case let .files(files) = note.bundle {
                if let first = files.first {
                    FileMemo(
                        url: first.url,
                        contentType: first.contentType,
                        highlightQuery: highlightQuery,
                        width: Metrics.tileSize * 2 + Metrics.spacing,
                        onTap: {
                            guard first.progress == nil else { return }
                            openFileURL(first.url)
                        }
                    )
                    .overlay {
                        if let progress = first.progress {
                            ProgressOverlay(progress: progress)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                    }
                    .allowsHitTesting(first.progress == nil)
                    .contextMenu {
                        Button { onOpenShareFiles([first.url]) } label: {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .tint(.primary)
                        Button(role: .destructive) {
                            onStartMultiDelete(note.id)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            else if case let .audio(audios) = note.bundle {
                if let first = audios.first {
                    AudioSquareTile(url: first.url, duration: first.duration, preferredLength: nil, titleOverride: nil, highlightQuery: highlightQuery)
                        .contextMenu {
                            Button { onOpenRecord(first.url) } label: {
                                Label("더보기", systemImage: "ellipsis.circle")
                            }
                            .tint(.primary)
                            Button {
                                NotificationCenter.default.post(name: .apexStopAllAudioPlayback, object: nil)
                                onOpenShareAudio(first.url)
                            } label: {
                                Label("공유", systemImage: "square.and.arrow.up")
                            }
                            .tint(.primary)
                            Button(role: .destructive) {
                                onStartMultiDelete(note.id)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    
                    // Filename + STT text under the audio tile
                    VStack(alignment: .leading, spacing: 4) {
                        let baseName = first.url.deletingPathExtension().lastPathComponent
                        let displayName = baseName.isEmpty ? "음성 메모" : baseName
                        if let attr = highlightedText(displayName, query: highlightQuery) {
                            Text(attr)
                                .font(.caption2)
                                .foregroundStyle(Color("BlackLabel"))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text(displayName)
                            .font(.caption2)
                            .foregroundStyle(Color("BlackLabel"))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        }
                        if let stt = note.text, !stt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if let attr = highlightedText(stt, query: highlightQuery) {
                                Text(attr)
                                    .font(.body6)
                                    .foregroundStyle(Color("BlackLabel"))
                            } else {
                                Text(stt)
                                    .font(.body6)
                                    .foregroundStyle(Color("BlackLabel"))
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(Color("BackgroundSecondary"))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }
            
            if let text = note.text {
                // For audio notes, STT is rendered directly under the audio tile above.
                if case .audio = note.bundle {
                    EmptyView()
                } else {
                VStack(alignment: .trailing, spacing: 8) {
                    SelectableText(
                        text,
                        fontSize: 14,
                        textStyle: .body,
                        lineSpacing: 4,
                        maxLayoutWidth: UIScreen.main.bounds.width - 24 - leadingReservedWidth,
                        highlightQuery: highlightQuery
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color("BackgroundSecondary"))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    ForEach(urls(in: text), id: \.absoluteString) { url in
                        LinkPreviewCard(url: url)
                    }
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button { onCopyText(text) } label: {
                        Label("전체 복사", systemImage: "doc.on.doc")
                    }
                    .tint(.primary)
                    Button { onStartEdit(note.id, text) } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    .tint(.primary)
                    Button { onOpenShare(text) } label: {
                        Label("공유", systemImage: "square.and.arrow.up")
                    }
                    .tint(.primary)
                    Button(role: .destructive) {
                        onStartMultiDelete(note.id)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                    .tint(.red)
                }
                }
            }
        }
        .alert("\(deleteSubjectText) 삭제하겠습니까?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) { pendingDelete?() }
            Button("취소", role: .cancel) { }
        }
    }
}

extension ChatMessageView {
    // Highlight helper for filename/STT to match global search behavior
    func highlightedText(_ text: String, query: String?) -> AttributedString? {
        guard let q = query?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty else { return nil }
        let mas = NSMutableAttributedString(string: text)
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var searchRange = fullRange
        while true {
            let found = ns.range(of: q, options: options, range: searchRange)
            if found.location == NSNotFound { break }
            mas.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.45), range: found)
            let nextLoc = found.location + found.length
            if nextLoc >= ns.length { break }
            searchRange = NSRange(location: nextLoc, length: ns.length - nextLoc)
        }
        return AttributedString(mas)
    }
    
    func tempURLForImageData(_ data: Data) -> URL? {
        let isPNG: Bool = data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let ext = isPNG ? "png" : "jpg"
        let filename = "apex-image-\(UUID().uuidString).\(ext)"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}


