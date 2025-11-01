//
//  MediaView.swift
//  APEX
//
//  Created by 조운경 on 10/28/25.
//

import SwiftUI
import AVFoundation
import Photos

enum MediaSource: Hashable {
    case image(Data)
    case video(URL)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .image(let data):
            hasher.combine(0)
            hasher.combine(data.count)
        case .video(let url):
            hasher.combine(1)
            hasher.combine(url)
        }
    }
}

struct MediaView: View {
    let items: [MediaSource]
    let title: String
    let uploadedAt: Date?
    var onSave: ((Int, MediaSource) -> Void)?
    var onDelete: ((Int, MediaSource) -> Void)?
    var onTitleTap: ((Int) -> Void)?
    @State private var selectedIndex: Int
    @State private var pages: [MediaSource]
    @Environment(\.dismiss) private var dismiss
    @State private var showChrome: Bool = true
    @State private var isVideoPlaying: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showShareOptions: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareAttachments: [ShareAttachmentItem] = []

    private var deleteObjectText: String {
        guard pages.indices.contains(selectedIndex) else { return "항목을" }
        switch pages[selectedIndex] {
        case .image:
            return "사진을"
        case .video:
            return "영상을"
        }
    }

    init(
        items: [MediaSource],
        selectedIndex: Int,
        title: String,
        uploadedAt: Date?,
        onSave: ((Int, MediaSource) -> Void)? = nil,
        onDelete: ((Int, MediaSource) -> Void)? = nil,
        onTitleTap: ((Int) -> Void)? = nil
    ) {
        self.items = items
        self.title = title
        self.uploadedAt = uploadedAt
        self.onSave = onSave
        self.onDelete = onDelete
        self.onTitleTap = onTitleTap
        _selectedIndex = State(initialValue: selectedIndex)
        _pages = State(initialValue: items)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !pages.isEmpty {
                TabView(selection: $selectedIndex, content: {
                    ForEach(pages.indices, id: \.self) { idx in
                        pageView(for: pages[idx])
                            .tag(idx)
                    }
                })
                .tabViewStyle(.page(indexDisplayMode: .never))
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        withAnimation(.easeInOut(duration: 0.2)) { showChrome = true }
                    }
                )
            }

            if showChrome {
                VStack(spacing: 0) {
                    MediaHeaderBar(
                        title: title,
                        uploadedAt: uploadedAt,
                        onBack: { dismiss() },
                        onGrid: { },
                        onTitleTap: {
                            if let onTitleTap { onTitleTap(selectedIndex) }
                            dismiss()
                        }
                    )
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(!isVideoPlaying)

                VStack(spacing: 0) {
                    Spacer()
                    MediaBottomBar(
                        index: selectedIndex,
                        total: pages.count,
                        onShare: { handleShareTapped() },
                        onSave: { handleSave() },
                        onDelete: { showDeleteAlert = true }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(!isVideoPlaying)
            }
        }
        .alert("\(deleteObjectText)을 삭제하시겠어요?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) { handleDelete() }
            Button("취소", role: .cancel) { }
        }
        .confirmationDialog("공유", isPresented: $showShareOptions, titleVisibility: .visible) {
            Button("묶음 전체 전달") { prepareShareAttachments(allInBundle: true) }
            Button("이 항목만 전달") { prepareShareAttachments(allInBundle: false) }
            Button("취소", role: .cancel) { }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareView(initialAttachments: shareAttachments)
                .background(Color("Background"))
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    @ViewBuilder
    private func pageView(for item: MediaSource) -> some View {
        switch item {
        case .image(let data):
            ImagePage(imageData: data)
        case .video(let url):
            VideoPage(url: url, showChrome: $showChrome, isPlayingExternal: $isVideoPlaying)
        }
    }
}

private extension MediaView {
    func handleShareTapped() {
        // If multiple items, offer bundle vs single; if single, go single directly
        if pages.count > 1 {
            showShareOptions = true
        } else {
            prepareShareAttachments(allInBundle: false)
        }
    }

    func prepareShareAttachments(allInBundle: Bool) {
        let targets: [MediaSource]
        if allInBundle {
            targets = pages
        } else {
            guard pages.indices.contains(selectedIndex) else { return }
            targets = [pages[selectedIndex]]
        }

        shareAttachments = targets.compactMap { source in
            switch source {
            case .image(let data):
                if let img = UIImage(data: data) {
                    return ShareAttachmentItem(id: UUID(), kind: .image(img))
                } else { return nil }
            case .video(let url):
                return ShareAttachmentItem(id: UUID(), kind: .video(url, thumbnail: generateThumbnail(for: url)))
            }
        }
        showShareSheet = true
        showShareOptions = false
    }
    func handleSave() {
        guard pages.indices.contains(selectedIndex) else { return }
        let item = pages[selectedIndex]
        if let onSave { onSave(selectedIndex, item) } else { defaultSave(item) }
    }

    func handleDelete() {
        guard pages.indices.contains(selectedIndex) else { return }
        let item = pages[selectedIndex]
        onDelete?(selectedIndex, item)
        var newPages = pages
        newPages.remove(at: selectedIndex)
        pages = newPages
        if selectedIndex >= pages.count { selectedIndex = max(0, pages.count - 1) }
        if pages.isEmpty { dismiss() }
    }

    func defaultSave(_ item: MediaSource) {
        switch item {
        case .image(let data):
            if let image = UIImage(data: data) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        case .video(let url):
            UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
        }
    }
}

private struct ImagePage: View {
    let imageData: Data

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(.white.opacity(0.8))
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct VideoPage: View {
    let url: URL
    @Binding var showChrome: Bool
    @Binding var isPlayingExternal: Bool
    @State private var thumb: UIImage?
    @State private var durationText: String = "00:00"
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var totalTime: Double = 0
    @State private var timeObserver: Any?
    @State private var volume: Double = 1.0
    @State private var hideWork: DispatchWorkItem?
    @State private var isScrubbing: Bool = false

    var body: some View {
        ZStack {
            if let player {
                ZStack {
                    PlayerContainerView(player: player)
                        .ignoresSafeArea()

                    if showChrome {
                        CircularProgressButton(
                            isPlaying: $isPlaying,
                            onToggle: { togglePlay() }
                        )
                    }
                }
                // 스크럽 중에는 투명 오버레이로 TabView 스와이프 흡수
                if isScrubbing {
                    Rectangle()
                        .fill(Color.clear)
                        .ignoresSafeArea()
                        .allowsHitTesting(true)
                }
            } else {
                Rectangle()
                    .fill(Color.black)
                    .overlay {
                        if let thumb {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                    }
                    .overlay(Color.black.opacity(0.35))
                    .ignoresSafeArea()

                VStack(spacing: 6) {
                    CircularProgressButton(
                        isPlaying: $isPlaying,
                        onToggle: { if isPlaying { togglePlay() } else { startPlayback() } }
                    )
                    // Show total duration only before the first playback (no player yet)
                    Text(durationText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
        }
        .task {
            if thumb == nil { thumb = generateThumbnail(for: url) }
            durationText = format(durationOf: url)
            // Ensure transport bar is visible initially by preloading duration
            let asset = AVAsset(url: url)
            let seconds = asset.duration.seconds
            if seconds.isFinite && seconds > 0 { totalTime = seconds }
        }
        .onDisappear { stopPlayback() }
        .onChange(of: showChrome) { _, isShown in
            if isShown && isPlaying { scheduleAutoHide() } else { cancelAutoHide() }
        }
        // Bottom auxiliary bar: progress (filling), time labels, and volume
        .overlay(alignment: .bottom) {
            if totalTime > 0 && showChrome {
                ZStack {
                    // 투명 제스처 차폐 레이어 (재생바 대역만 스와이프 흡수)
                    BottomGestureShield(height: 68)

                    MediaPlaybackBar(
                        current: $currentTime,
                        total: $totalTime,
                        volume: Binding(
                            get: { volume },
                            set: { newVal in
                                volume = newVal
                                player?.volume = Float(newVal)
                            }
                        ),
                        onScrub: { newSeconds in seek(to: newSeconds) },
                        onScrubBegan: {
                            isScrubbing = true
                            cancelAutoHide()
                        },
                        onScrubEnded: {
                            isScrubbing = false
                            if isPlaying { scheduleAutoHide() }
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 84)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(!isPlayingExternal)
            }
        }
    }

    private func startPlayback() {
        if player == nil {
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { _ in
                isPlaying = false
                isPlayingExternal = false
            }
            // time observer
            let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
            timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                let seconds = CMTimeGetSeconds(time)
                currentTime = max(0, seconds)
                if let duration = newPlayer.currentItem?.duration.seconds, duration.isFinite {
                    totalTime = duration
                } else {
                    totalTime = 0
                }
            }
        }
        if let player {
            if player.currentItem == nil {
                player.replaceCurrentItem(with: AVPlayerItem(url: url))
            }
            player.play()
        }
        isPlaying = true
        isPlayingExternal = true
        withAnimation { showChrome = true }
        scheduleAutoHide()
    }

    private func stopPlayback() {
        player?.pause()
        if let obs = timeObserver, let player { player.removeTimeObserver(obs) }
        timeObserver = nil
        isPlaying = false
        isPlayingExternal = false
        cancelAutoHide()
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            isPlayingExternal = false
            cancelAutoHide()
            withAnimation { showChrome = true }
        } else {
            player.play()
            isPlaying = true
            isPlayingExternal = true
            withAnimation { showChrome = true }
            scheduleAutoHide()
        }
    }

    private func seek(to value: Double) {
        guard let player else { return }
        cancelAutoHide()
        let seconds = max(0, min(value, totalTime))
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
        if isPlaying { scheduleAutoHide() }
    }

    private func formatClock(_ seconds: Double) -> String {
        let rounded = Int(seconds.rounded())
        let minutes = rounded / 60
        let secs = rounded % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func scheduleAutoHide(after seconds: Double = 2.5) {
        cancelAutoHide()
        guard isPlaying else { return }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) { showChrome = false }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func cancelAutoHide() {
        hideWork?.cancel()
        hideWork = nil
    }
}

private struct ProgressSeekBar: View {
    @Binding var current: Double
    @Binding var total: Double
    var onScrub: (Double) -> Void

    @GestureState private var isDragging: Bool = false

    private func progress() -> Double { total > 0 ? max(0, min(current / total, 1)) : 0 }

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let height = max(6, geo.size.height)
            let pct = progress()
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: height)
                Capsule()
                    .fill(Color("Primary"))
                    .frame(width: width * CGFloat(pct), height: height)
                Circle()
                    .fill(Color.white)
                    .frame(width: height + 6.0, height: height + 6.0)
                    .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                    .offset(
                        x: max(
                            0,
                            min(
                                width - (height + 6.0),
                                (width * CGFloat(pct)) - (height + 6.0) / 2.0
                            )
                        )
                    )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        let clampedX = max(0, min(width, value.location.x))
                        let ratio = Double(clampedX) / Double(width)
                        let newSeconds = (total > 0) ? (ratio * total) : 0
                        current = newSeconds
                        onScrub(newSeconds)
                    }
            )
        }
    }
}

private struct BottomGestureShield: View {
    let height: CGFloat
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: height)
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 0))
            .simultaneousGesture(TapGesture().onEnded({}))
            .ignoresSafeArea(edges: .bottom)
    }
}

// Minimal AVPlayerLayer-backed view (aspect-fit)
private final class PlayerHostView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer {
        guard let layer = self.layer as? AVPlayerLayer else { return AVPlayerLayer() }
        return layer
    }
}

private struct PlayerContainerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerHostView {
        let hostView = PlayerHostView()
        hostView.playerLayer.player = player
        hostView.playerLayer.videoGravity = .resizeAspect
        return hostView
    }
    func updateUIView(_ uiView: PlayerHostView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = .resizeAspect
    }
}

private struct CircularProgressButton: View {
    @Binding var isPlaying: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: { onToggle() }, label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.black.opacity(0.45))
                .clipShape(Circle())
        })
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
    generator.maximumSize = CGSize(width: 1600, height: 1600)
    do {
        let cgImage = try generator.copyCGImage(at: .init(seconds: 0.1, preferredTimescale: 600), actualTime: nil)
        return UIImage(cgImage: cgImage)
    } catch {
        return nil
    }
}

#Preview {
    MediaView(items: [.image(Data())], selectedIndex: 0, title: "Gyeong", uploadedAt: Date())
}

#Preview("Play Button") {
    CircularProgressButton(
        isPlaying: .constant(true),
        onToggle: {}
    )
}
