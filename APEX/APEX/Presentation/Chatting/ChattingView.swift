//
//  ChattingView.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import SwiftUI
import AVFoundation
import LinkPresentation
import Combine
import UniformTypeIdentifiers

struct ChattingView: View {
    @State private var notes: [Note] = []
    @State private var isMediaSheetVisible: Bool = false
    @State private var stagedAttachments: [ShareAttachmentItem] = []
    @State private var bottomBarOffsetY: CGFloat = 0

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .trailing, spacing: 6) {
                    ForEach(notes) { note in
                        ChatMessageView(
                            note: note,
                            buildViewerPayload: { anchor in
                                buildGlobalViewerPayload(startingFrom: anchor)
                            },
                            onDelete: { anchor in
                                deleteMedia(anchor: anchor)
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                    Color.clear.frame(height: 8)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            APEXNavigationBar(
                .memo(
                    title: "Gyeong",
                    onBack: { },
                    onSearch: { },
                    onMenu: { }
                )
            )
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !stagedAttachments.isEmpty {
                    AttachBar(items: stagedAttachments) { removed in
                        stagedAttachments.removeAll { $0.id == removed.id }
                    }
                }

                InputBar({ note in
                    handleIncoming(note: note)
                }, onSheetVisibilityChanged: { visible in
                    isMediaSheetVisible = visible
                }, stagedAttachments: $stagedAttachments, onBarOffsetChanged: { offset in
                    bottomBarOffsetY = offset
                })
            }
            .offset(y: bottomBarOffsetY)
            .padding(.bottom, isMediaSheetVisible ? 0 : 34)
        }
    }
}

// MARK: - Send handling & simulated uploads

private extension ChattingView {
    func buildGlobalViewerPayload(startingFrom anchor: ChatMessageView.ChatAnchor) -> (items: [MediaSource], anchors: [ChatMessageView.ChatAnchor], index: Int) {
        var allItems: [MediaSource] = []
        var allAnchors: [ChatMessageView.ChatAnchor] = []
        for noteItem in notes {
            if case let .media(images, videos) = noteItem.bundle {
                struct Combined { let isImage: Bool; let index: Int; let order: Int }
                var merged: [Combined] = []
                for imageIndex in images.indices {
                    let order = images[imageIndex].orderIndex ?? imageIndex
                    merged.append(Combined(isImage: true, index: imageIndex, order: order))
                }
                for videoIndex in videos.indices {
                    let order = videos[videoIndex].orderIndex ?? (images.count + videoIndex)
                    merged.append(Combined(isImage: false, index: videoIndex, order: order))
                }
                merged.sort { $0.order < $1.order }
                for entry in merged {
                    if entry.isImage {
                        allItems.append(.image(images[entry.index].data))
                        allAnchors.append(.init(noteId: noteItem.id, isImage: true, localIndex: entry.index))
                    } else {
                        allItems.append(.video(videos[entry.index].url))
                        allAnchors.append(.init(noteId: noteItem.id, isImage: false, localIndex: entry.index))
                    }
                }
            }
        }
        let start = allAnchors.firstIndex(where: { $0.noteId == anchor.noteId && $0.isImage == anchor.isImage && $0.localIndex == anchor.localIndex }) ?? 0
        return (items: allItems, anchors: allAnchors, index: start)
    }

    func handleIncoming(note: Note) {
        var noteWithProgress = note
        if case let .media(images, videos) = note.bundle {
            // Preserve orderIndex; just reset progress for simulated upload
            let imagesWithProgress = images.map {
                ImageAttachment(
                    data: $0.data,
                    progress: 0,
                    orderIndex: $0.orderIndex
                )
            }
            let videosWithProgress = videos.map { VideoAttachment(url: $0.url, progress: 0, orderIndex: $0.orderIndex) }
            noteWithProgress.bundle = .media(images: imagesWithProgress, videos: videosWithProgress)
        }
        notes.append(noteWithProgress)
        if let idx = notes.indices.last { startUploadsForNote(at: idx) }
    }

    func startUploadsForNote(at index: Int) {
        guard notes.indices.contains(index) else { return }
        let noteId = notes[index].id
        if case let .media(images, videos) = notes[index].bundle {
            for imageIndex in images.indices { simulateImageUpload(noteId: noteId, imageIndex: imageIndex) }
            for videoIndex in videos.indices { simulateVideoUpload(noteId: noteId, videoIndex: videoIndex) }
        } else if case let .files(files) = notes[index].bundle {
            for fileIndex in files.indices { simulateFileUpload(noteId: noteId, fileIndex: fileIndex) }
        }
    }

    func simulateImageUpload(noteId: UUID, imageIndex: Int) {
        Task { @MainActor in
            let steps = 20
            for step in 0...steps {
                setImageProgress(noteId: noteId, imageIndex: imageIndex, value: Double(step) / Double(steps))
                try? await Task.sleep(nanoseconds: 80_000_000) // 0.08s
            }
            setImageProgress(noteId: noteId, imageIndex: imageIndex, value: nil)
        }
    }

    func simulateVideoUpload(noteId: UUID, videoIndex: Int) {
        Task { @MainActor in
            let steps = 30
            for step in 0...steps {
                setVideoProgress(noteId: noteId, videoIndex: videoIndex, value: Double(step) / Double(steps))
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
            setVideoProgress(noteId: noteId, videoIndex: videoIndex, value: nil)
        }
    }

    func simulateFileUpload(noteId: UUID, fileIndex: Int) {
        Task { @MainActor in
            let steps = 25
            for step in 0...steps {
                setFileProgress(noteId: noteId, fileIndex: fileIndex, value: Double(step) / Double(steps))
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
            setFileProgress(noteId: noteId, fileIndex: fileIndex, value: nil)
        }
    }

    func setImageProgress(noteId: UUID, imageIndex: Int, value: Double?) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .media(images, videos) = notes[idx].bundle, images.indices.contains(imageIndex) else { return }
        images[imageIndex].progress = value
        notes[idx].bundle = .media(images: images, videos: videos)
    }

    func setVideoProgress(noteId: UUID, videoIndex: Int, value: Double?) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .media(images, videos) = notes[idx].bundle, videos.indices.contains(videoIndex) else { return }
        videos[videoIndex].progress = value
        notes[idx].bundle = .media(images: images, videos: videos)
    }

    func setFileProgress(noteId: UUID, fileIndex: Int, value: Double?) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .files(files) = notes[idx].bundle, files.indices.contains(fileIndex) else { return }
        files[fileIndex].progress = value
        notes[idx].bundle = .files(files)
    }
}

private struct ChatMessageView: View {
    let note: Note
    struct ChatAnchor { let noteId: UUID; let isImage: Bool; let localIndex: Int }
    let buildViewerPayload: (ChatAnchor) -> (items: [MediaSource], anchors: [ChatAnchor], index: Int)
    let onDelete: (ChatAnchor) -> Void
    private struct ViewerPayload: Identifiable {
        let id = UUID()
        let items: [MediaSource]
        let anchors: [ChatAnchor]
        let index: Int
    }
    @State private var viewer: ViewerPayload?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let text = note.text {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text)
                        .font(.body2)
                        .foregroundStyle(Color.primary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    ForEach(urls(in: text), id: \.absoluteString) { url in
                        LinkPreviewCard(url: url)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

            if case let .media(images, videos) = note.bundle {
                if videos.count == 1, images.isEmpty {
                    SingleVideoCard(url: videos[0].url) {
                        openViewer(anchor: ChatAnchor(noteId: note.id, isImage: false, localIndex: 0))
                    }
                } else if images.count == 1, videos.isEmpty {
                    SingleImageCard(imageData: images[0].data) {
                        openViewer(anchor: ChatAnchor(noteId: note.id, isImage: true, localIndex: 0))
                    }
                } else {
                    MediaGrid(images: images, videos: videos) { isImage, localIndex in
                        openViewer(anchor: ChatAnchor(noteId: note.id, isImage: isImage, localIndex: localIndex))
                    }
                }
            } else if case let .files(files) = note.bundle {
                FilesGrid(files: files)
            }
            // Audio attachments: render as square tiles per design
            else if case let .audio(audios) = note.bundle {
                if audios.count == 1 {
                    AudioSquareTile(url: audios[0].url, duration: audios[0].duration)
                } else {
                    let columns = [
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2)
                    ]
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(audios.indices, id: \.self) { idx in
                            AudioGridTile(url: audios[idx].url, duration: audios[idx].duration)
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $viewer) { payload in
            MediaView(
                items: payload.items,
                selectedIndex: payload.index,
                title: clientName(from: note),
                uploadedAt: note.uploadedAt,
                onDelete: { removedIndex, _ in
                    guard payload.anchors.indices.contains(removedIndex) else { return }
                    onDelete(payload.anchors[removedIndex])
                }
            )
        }
    }

    private func openViewer(anchor: ChatAnchor) {
        let payload = buildViewerPayload(anchor)
        viewer = ViewerPayload(items: payload.items, anchors: payload.anchors, index: payload.index)
    }
}

private extension ChattingView {
    func deleteMedia(anchor: ChatMessageView.ChatAnchor) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == anchor.noteId }) else { return }
        guard case var .media(images, videos) = notes[noteIndex].bundle else { return }

        if anchor.isImage {
            guard images.indices.contains(anchor.localIndex) else { return }
            images.remove(at: anchor.localIndex)
        } else {
            guard videos.indices.contains(anchor.localIndex) else { return }
            videos.remove(at: anchor.localIndex)
        }

        // Recompute contiguous orderIndex across all remaining media (images + videos)
        struct Combined { let isImage: Bool; let idx: Int; let order: Int }
        var merged: [Combined] = []
        for i in images.indices {
            let order = images[i].orderIndex ?? i
            merged.append(Combined(isImage: true, idx: i, order: order))
        }
        for v in videos.indices {
            let order = videos[v].orderIndex ?? (images.count + v)
            merged.append(Combined(isImage: false, idx: v, order: order))
        }
        merged.sort { $0.order < $1.order }
        for (newOrder, entry) in merged.enumerated() {
            if entry.isImage { images[entry.idx].orderIndex = newOrder } else { videos[entry.idx].orderIndex = newOrder }
        }

        notes[noteIndex].bundle = .media(images: images, videos: videos)
    }
}

private func clientName(from note: Note) -> String {
    // Placeholder until Note carries author/client info. Using a hardcoded title like the nav bar.
    return "Gyeong"
}

// Single video: center play button, duration below
private struct SingleVideoCard: View {
    let url: URL
    @State private var thumb: UIImage?
    @State private var duration: String = "00:00"
    var onTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Rectangle()
                    .foregroundStyle(Color.gray.opacity(0.15))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        if let thumb {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .overlay(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(spacing: 2) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color("Background"))
                        .shadow(radius: 4)

                    Text(duration)
                        .font(.caption1)
                        .foregroundStyle(Color("Background"))
                }
            }
            .frame(width: 240)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
        }
        .task {
            if thumb == nil { thumb = generateThumbnail(for: url) }
            duration = format(durationOf: url)
        }
    }
}

// Single image: fixed width 240, height fits content
private struct SingleImageCard: View {
    let imageData: Data
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?() }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 240, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?() }
            }
        }
    }
}

// Grid for mixed media; videos show duration badge bottom-left
private struct MediaGrid: View {
    let images: [ImageAttachment]
    let videos: [VideoAttachment]
    var onOpen: (_ isImage: Bool, _ localIndex: Int) -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

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

        // Render LTR and right-align the last row using leading placeholders (3-column grid)
        let remainder = merged.count % 3
        let paddingCount = remainder == 0 ? 0 : (3 - remainder)
        let fullCount = merged.count - remainder
        let leadingPlaceholders = Array(repeating: Optional<Int>.none, count: paddingCount)
        let fullRows = Array(0..<fullCount).map { Optional($0) }
        let lastRow = (remainder > 0 ? Array(fullCount..<merged.count).map { Optional($0) } : [])
        let displayOrder: [Int?] = fullRows + leadingPlaceholders + lastRow

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(displayOrder.indices, id: \.self) { slotIndex in
                if let mergedIndex = displayOrder[slotIndex] {
                    let item = merged[mergedIndex]
                    if item.isImage {
                        let img = images[item.index]
                        ZStack {
                            if let uiImage = UIImage(data: img.data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 116.33, height: 124)
                                    .clipped()
                                    .cornerRadius(10)
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.15))
                                    .frame(width: 121, height: 124)
                            }
                            if let progress = img.progress {
                                ProgressOverlay(progress: progress)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(true, item.index) }
                    } else {
                        let video = videos[item.index]
                        ZStack {
                            VideoThumbTile(url: video.url)
                            if let progress = video.progress {
                                ProgressOverlay(progress: progress)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(false, item.index) }
                    }
                } else {
                    // Invisible placeholder to push the last row to the right
                    Color.clear
                        .frame(height: 124)
                }
            }
        }
    }
}

private struct FilesGrid: View {
    let files: [FileAttachment]

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(files.indices, id: \.self) { idx in
                FileGridTile(file: files[idx])
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct FileGridTile: View {
    let file: FileAttachment

    var body: some View {
        ZStack {
            Color("BackgroundSecondary")

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: fileSystemSymbolName(for: file.contentType, url: file.url))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black)

                Spacer()

                Text(file.url.lastPathComponent)
                    .font(.caption2)
                    .lineLimit(4)
                    .truncationMode(.middle)
                    .foregroundStyle(.black)
                    .padding(.bottom, 4)

                if let sizeText = fileSizeText(for: file.url) {
                    Text(sizeText)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            .padding(12)

            if let progress = file.progress {
                ProgressOverlay(progress: progress)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .cornerRadius(10)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func fileSizeText(for url: URL) -> String? {
        if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        return nil
    }
}

private func fileSystemSymbolName(for type: UTType?, url: URL?) -> String {
    var resolvedType: UTType? = type
    if resolvedType == nil, let ext = url?.pathExtension, !ext.isEmpty {
        resolvedType = UTType(filenameExtension: ext)
    }
    guard let resolved = resolvedType else { return "document" }
    if resolved.conforms(to: .image) { return "photo" }
    if resolved.conforms(to: .movie) || resolved.conforms(to: .audiovisualContent) { return "video" }
    return "document"
}

private struct VideoThumbTile: View {
    let url: URL
    @State private var thumb: UIImage?
    @State private var duration: String = "00:00"

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .foregroundStyle(Color.gray.opacity(0.15))
                .frame(height: 124)
                .overlay {
                    if let thumb {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .overlay(Color.black.opacity(0.4))
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(duration)
                .font(.caption1)
                .foregroundStyle(.white)
                .padding(12)
        }
        .task {
            if thumb == nil { thumb = generateThumbnail(for: url) }
            duration = format(durationOf: url)
        }
    }
}

// MARK: - Video helpers

// Translucent overlay with circular progress and percentage
private struct ProgressOverlay: View {
    let progress: Double // 0...1
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
        }
    }
}

private func format(durationOf url: URL) -> String {
    let asset = AVAsset(url: url)
    let seconds = Int(CMTimeGetSeconds(asset.duration).rounded())
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

private func generateThumbnail(for url: URL) -> UIImage? {
    let asset = AVAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1200, height: 1200)
    do {
        let cgImage = try generator.copyCGImage(at: .init(seconds: 0.1, preferredTimescale: 600), actualTime: nil)
        return UIImage(cgImage: cgImage)
    } catch {
        return nil
    }
}

// MARK: - Link detection & preview

private func urls(in text: String, limit: Int = 3) -> [URL] {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let textAsNSString = text as NSString
    let fullRange = NSRange(location: 0, length: textAsNSString.length)
    let matches = detector?.matches(in: text, options: [], range: fullRange) ?? []
    var seen = Set<String>()
    var extractedURLs: [URL] = []
    for match in matches {
        guard let range = Range(match.range, in: text) else { continue }
        let substring = String(text[range])
        guard let url = URL(string: substring) else { continue }
        if seen.insert(url.absoluteString).inserted {
            extractedURLs.append(url)
            if extractedURLs.count >= limit { break }
        }
    }
    return extractedURLs
}

private final class LinkPreviewLoader: ObservableObject {
    @Published var metadata: LPLinkMetadata?
    private static let cache = NSCache<NSURL, LPLinkMetadata>()
    private let provider = LPMetadataProvider()
    private let url: URL

    init(url: URL) {
        self.url = url
        if let cached = Self.cache.object(forKey: url as NSURL) {
            self.metadata = cached
        } else {
            provider.startFetchingMetadata(for: url) { [weak self] meta, _ in
                DispatchQueue.main.async {
                    if let meta {
                        Self.cache.setObject(meta, forKey: self?.url as NSURL? ?? NSURL())
                    }
                    self?.metadata = meta
                }
            }
        }
    }
}

private struct LinkPreviewViewRepresentable: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        let linkView = LPLinkView(metadata: metadata)
        linkView.translatesAutoresizingMaskIntoConstraints = false
        return linkView
    }
    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}

private struct LinkPreviewCard: View {
    let url: URL
    @StateObject private var loader: LinkPreviewLoader

    init(url: URL) {
        self.url = url
        _loader = StateObject(wrappedValue: LinkPreviewLoader(url: url))
    }

    var body: some View {
        Group {
            if let meta = loader.metadata {
                LinkPreviewViewRepresentable(metadata: meta)
                    .frame(width: 250, height: 184)
                    .background(.regularMaterial)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.15))
                    ProgressView().tint(.secondary)
                }
                .frame(height: 120)
            }
        }
    }
}

// Square audio tile (single)
private struct AudioSquareTile: View {
    let url: URL
    let duration: TimeInterval?
    @State private var isPlaying: Bool = false
    @State private var player: AVAudioPlayer?
    @State private var durationText: String = "--:--"
    @State private var stopWork: DispatchWorkItem?

    var body: some View {
        Button {
            if isPlaying { stopPlayback() } else { startPlayback() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black)
                Spacer()
                Text(titleText())
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.black)
                    .padding(.bottom, 4)
                Text(durationText)
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .padding(12)
            .background(Color("BackgroundSecondary"))
            .aspectRatio(1, contentMode: .fit)
            .frame(width: 124)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .onAppear { updateDuration() }
        .onDisappear { stopPlayback() }
    }

    private func updateDuration() {
        if let duration, duration > 0 {
            durationText = format(duration)
            return
        }
        if let tmp = try? AVAudioPlayer(contentsOf: url) {
            durationText = format(tmp.duration)
            return
        }
        let asset = AVAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        if seconds.isFinite && seconds > 0 { durationText = format(seconds) } else { durationText = "--:--" }
    }

    private func startPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.defaultToSpeaker])
            try? session.setActive(true)
            if player == nil { player = try AVAudioPlayer(contentsOf: url) }
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            scheduleStopObserver()
        } catch {
            isPlaying = false
        }
    }

    private func stopPlayback() {
        stopWork?.cancel(); stopWork = nil
        player?.stop()
        isPlaying = false
    }

    private func scheduleStopObserver() {
        stopWork?.cancel()
        guard let player else { return }
        let remaining = max(0, player.duration - player.currentTime)
        let work = DispatchWorkItem { self.isPlaying = false }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
    }

    private func titleText() -> String {
        let base = url.deletingPathExtension().lastPathComponent
        return base.isEmpty ? "음성 메모" : base
    }
}

// Square audio tile (grid item)
private struct AudioGridTile: View {
    let url: URL
    let duration: TimeInterval?
    @State private var isPlaying: Bool = false
    @State private var player: AVAudioPlayer?
    @State private var durationText: String = "--:--"
    @State private var stopWork: DispatchWorkItem?

    var body: some View {
        Button {
            if isPlaying { stopPlayback() } else { startPlayback() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.opacity(0.15))
                VStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    Text(titleText())
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.white)
                    Text(durationText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(8)
            }
            .aspectRatio(1, contentMode: .fill)
        }
        .buttonStyle(.plain)
        .onAppear { updateDuration() }
        .onDisappear { stopPlayback() }
    }

    private func updateDuration() {
        if let duration, duration > 0 {
            durationText = format(duration)
            return
        }
        if let tmp = try? AVAudioPlayer(contentsOf: url) {
            durationText = format(tmp.duration)
            return
        }
        let asset = AVAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        if seconds.isFinite && seconds > 0 { durationText = format(seconds) } else { durationText = "--:--" }
    }

    private func startPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.defaultToSpeaker])
            try? session.setActive(true)
            if player == nil { player = try AVAudioPlayer(contentsOf: url) }
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            scheduleStopObserver()
        } catch {
            isPlaying = false
        }
    }

    private func stopPlayback() {
        stopWork?.cancel(); stopWork = nil
        player?.stop()
        isPlaying = false
    }

    private func scheduleStopObserver() {
        stopWork?.cancel()
        guard let player else { return }
        let remaining = max(0, player.duration - player.currentTime)
        let work = DispatchWorkItem { self.isPlaying = false }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
    }

    private func titleText() -> String {
        let base = url.deletingPathExtension().lastPathComponent
        return base.isEmpty ? "음성 메모" : base
    }
}

private func format(_ duration: TimeInterval?) -> String {
    guard let duration else { return "--:--" }
    let total = Int(duration.rounded())
    let minutes = total / 60
    let seconds = total % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

#Preview {
    ChattingView()
}
