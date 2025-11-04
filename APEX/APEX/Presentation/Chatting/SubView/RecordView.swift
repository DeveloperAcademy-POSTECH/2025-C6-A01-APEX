//
//  RecordView.swift
//  APEX
//
//  Created by 조운경 on 10/30/25.
//

import SwiftUI
import AVFoundation

struct RecordView: View {
    let audioURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet: Bool = false
    @State private var filenameText: String = ""

    // Playback
    @State private var player: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var totalTime: Double = 0
    @State private var workingURL: URL?

    // Trim range (seconds)
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var isDraggingStart: Bool = false
    @State private var isDraggingEnd: Bool = false

    // Timer
    @State private var timeObserver: Timer?
    @State private var showDeleteAlert: Bool = false
    @State private var isKeyboardShown: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 0) {

                // Square audio tile (ChattingView UI, larger for editor)
                HStack {
                    Spacer(minLength: 0)
                    if let url = workingURL ?? audioURL {
                        AudioSquareTile(
                            url: url,
                            duration: resolveDuration(for: url),
                            preferredLength: 174,
                            titleOverride: filenameText
                        )
                        .allowsHitTesting(false)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color("BackgroundSecondary"))
                            .frame(width: 240, height: 240)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 24)

                // Play/Pause button
                Button(action: { togglePlay() }, label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Color("Primary"))
                        .clipShape(Circle())
                })
                .buttonStyle(.plain)
                .padding(.top, 16)

                // Playback bar (reused)
                MediaPlaybackBar(
                    current: $currentTime,
                    total: $totalTime,
                    volume: Binding(
                        get: { Double(player?.volume ?? 1.0) },
                        set: { newVal in player?.volume = Float(newVal) }
                    ),
                    onScrub: { newSeconds in
                        seek(to: newSeconds)
                    },
                    onScrubBegan: { isPlaying = false; player?.pause() },
                    onScrubEnded: {
                        if player != nil {
                            player?.play()
                            isPlaying = true
                        }
                    },
                    timeColor: .gray,
                    trackColor: Color.gray.opacity(0.25)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Filename editor
                APEXTextField(
                    kind: .singleLine,
                    label: "파일 이름",
                    placeholder: "파일 이름 입력",
                    text: $filenameText,
                    state: .normal(helper: nil),
                    isRequired: false,
                    isDisabled: false,
                    showsClearButton: true
                )
                .id("filenameField")
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
        }
        // Allow programmatic scrolling only when keyboard is shown
        .scrollDisabled(!isKeyboardShown)
        .background(Color("Background"))
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaBar(edge: .top) {
            APEXRecordTopBar(
                onClose: { dismiss() },
                onDone: { saveAudio(); dismiss() }
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer() // 전체 높이 채운 뒤 아래로 밀기
                    HStack(spacing: 48) {
                        Button(action: { saveAudio() }) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .glassEffect()
                        }
                        .buttonStyle(.plain)

                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .glassEffect()
                        }
                        .buttonStyle(.plain)

                        Button(action: { deleteAudio() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .glassEffect()
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.bottom, proxy.safeAreaInsets.bottom) // 홈 인디케이터 보정
                    .background(Color("Background"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 전체 영역 채우기
            }
            .ignoresSafeArea(.keyboard, edges: .bottom) // 키보드 올라와도 고정
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = workingURL ?? audioURL {
                ShareView(initialAttachments: [ShareAttachmentItem(id: UUID(), kind: .audio(url))])
            } else {
                ShareView()
            }
        }
        .alert("음성 녹음을 삭제할까요?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                guard let oldURL = workingURL ?? audioURL else { return }
                // Stop playback
                teardown()
                // Preserve existing shares by copying to app-managed storage and notifying rename
                let preservedURL = ensureSharedAudioCopy(of: oldURL)
                NotificationCenter.default.post(
                    name: .apexAudioRenamed,
                    object: nil,
                    userInfo: ["oldURL": oldURL, "newURL": preservedURL]
                )
                // Remove original file
                try? FileManager.default.removeItem(at: oldURL)
                dismiss()
            }
            Button("취소", role: .cancel) { }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.apexDismissKeyboard()
            }
        )
        .onAppear {
            workingURL = audioURL
            setupPlayerIfNeeded()
            filenameText = defaultTitle()
        }
        .onDisappear { teardown() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardShown = true
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("filenameField", anchor: .bottom)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { _ in
            if isKeyboardShown {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("filenameField", anchor: .bottom)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardShown = false
        }
        }
    }

    // MARK: - Helpers
    private func normalizedTrimStart() -> Double {
        guard totalTime > 0 else { return 0 }
        return max(0, min(trimStart / totalTime, 1))
    }
    private func normalizedTrimEnd() -> Double {
        guard totalTime > 0 else { return 1 }
        return max(0, min(trimEnd / totalTime, 1))
    }

    private func setupPlayerIfNeeded() {
        guard player == nil, let url = workingURL ?? audioURL else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.defaultToSpeaker])
            try? session.setActive(true)

            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.prepareToPlay()
            player = audioPlayer
            totalTime = audioPlayer.duration
            trimStart = 0
            trimEnd = audioPlayer.duration
            startTimer()
        } catch {
            player = nil
        }
    }

    private func startTimer() {
        timeObserver?.invalidate()
        timeObserver = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard let audioPlayer = player else { return }
            currentTime = audioPlayer.currentTime
            totalTime = audioPlayer.duration
            if !audioPlayer.isPlaying { isPlaying = false }
            if currentTime >= trimEnd { audioPlayer.pause(); isPlaying = false }
        }
    }

    private func teardown() {
        timeObserver?.invalidate(); timeObserver = nil
        player?.stop(); player = nil
        isPlaying = false
    }

    private func togglePlay() {
        guard let audioPlayer = player else { return }
        if isPlaying {
            audioPlayer.pause(); isPlaying = false
        } else {
            if currentTime < trimStart || currentTime >= trimEnd {
                audioPlayer.currentTime = trimStart
            }
            audioPlayer.play(); isPlaying = true
        }
    }

    private func seek(by delta: Double) {
        guard let audioPlayer = player else { return }
        let next = max(0, min(audioPlayer.duration, audioPlayer.currentTime + delta))
        audioPlayer.currentTime = next
        currentTime = next
    }

    private func seek(to seconds: Double) {
        guard let audioPlayer = player else { return }
        let next = max(0, min(audioPlayer.duration, seconds))
        audioPlayer.currentTime = next
        currentTime = next
    }

    private func assetDuration(for url: URL) -> TimeInterval? {
        let asset = AVAsset(url: url)
        let sec = asset.duration.seconds
        return sec.isFinite && sec > 0 ? sec : nil
    }

    private func resolveDuration(for url: URL) -> TimeInterval? {
        if totalTime > 0 { return totalTime }
        if let asset = assetDuration(for: url) { return asset }
        if let audioDurationPlayer = try? AVAudioPlayer(contentsOf: url) { return audioDurationPlayer.duration }
        return nil
    }

    private func reRecord() {
        // Placeholder: integrate with in-app recorder if needed
    }

    private func deleteAudio() {
        showDeleteAlert = true
    }

    // MARK: - File helpers
    private func ensureSharedAudioCopy(of sourceURL: URL) -> URL {
        let fm = FileManager.default
        // Target directory under Documents/SharedAudios
        let baseDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? sourceURL.deletingLastPathComponent()
        let sharedDir = baseDir.appendingPathComponent("SharedAudios", isDirectory: true)
        if !fm.fileExists(atPath: sharedDir.path) {
            try? fm.createDirectory(at: sharedDir, withIntermediateDirectories: true)
        }
        let name = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        var dest = sharedDir.appendingPathComponent(name).appendingPathExtension(ext)
        var counter = 2
        while fm.fileExists(atPath: dest.path) {
            dest = sharedDir.appendingPathComponent("\(name) \(counter)").appendingPathExtension(ext)
            counter += 1
        }
        if sourceURL == dest { return dest }
        if fm.fileExists(atPath: dest.path) == false {
            try? fm.copyItem(at: sourceURL, to: dest)
        }
        return dest
    }

    private func saveAudio() {
        guard let fromURL = workingURL ?? audioURL else { return }
        let sanitized = filenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return }

        let currentBase = fromURL.deletingPathExtension().lastPathComponent
        let ext = fromURL.pathExtension.isEmpty ? "m4a" : fromURL.pathExtension
        let baseDir = fromURL.deletingLastPathComponent()

        // If name hasn't actually changed, do nothing
        if sanitized == currentBase { return }

        var target = baseDir.appendingPathComponent(sanitized).appendingPathExtension(ext)
        var counter = 2
        // Only resolve conflicts against other files, not self
        while FileManager.default.fileExists(atPath: target.path) && target != fromURL {
            target = baseDir.appendingPathComponent("\(sanitized) \(counter)").appendingPathExtension(ext)
            counter += 1
        }

        // If target resolves to current file, no move needed
        if target == fromURL { return }

        do {
            try FileManager.default.moveItem(at: fromURL, to: target)
            workingURL = target
            // Rebuild player to point at new URL
            teardown()
            setupPlayerIfNeeded()
            filenameText = target.deletingPathExtension().lastPathComponent
            NotificationCenter.default.post(
                name: .apexAudioRenamed,
                object: nil,
                userInfo: ["oldURL": fromURL, "newURL": target]
            )
        } catch {
            // no-op: keep old name if move failed
        }
    }

    private func defaultTitle() -> String {
        guard let url = workingURL ?? audioURL else { return "음성 메모" }
        let base = url.deletingPathExtension().lastPathComponent
        return base.isEmpty ? "음성 메모" : base
    }

    private func formatClock(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let rounded = Int(seconds.rounded())
        let minutes = rounded / 60
        let secs = rounded % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// Trim handles overlay
private struct TrimHandles: View {
    let total: Double
    @Binding var start: Double
    @Binding var end: Double
    @Binding var isDraggingStart: Bool
    @Binding var isDraggingEnd: Bool

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let height = max(1, geo.size.height)
            let startX = CGFloat(max(0, min(start / max(total, 0.0001), 1))) * width
            let endX = CGFloat(max(0, min(end / max(total, 0.0001), 1))) * width

            ZStack(alignment: .topLeading) {
                // Start handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 4, height: height)
                    .contentShape(Rectangle())
                    .position(x: startX, y: height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let ratio = max(0, min(1, value.location.x / width))
                                start = min(end - 0.1, ratio * total)
                                isDraggingStart = true
                            }
                            .onEnded { _ in isDraggingStart = false }
                    )

                // End handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 4, height: height)
                    .contentShape(Rectangle())
                    .position(x: endX, y: height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let ratio = max(0, min(1, value.location.x / width))
                                end = max(start + 0.1, ratio * total)
                                isDraggingEnd = true
                            }
                            .onEnded { _ in isDraggingEnd = false }
                    )
            }
        }
    }
}

// Simple scrub slider
private struct ScrubSlider: View {
    @Binding var current: Double
    let total: Double
    var onScrub: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let height = max(6, geo.size.height)
            let progress = total > 0 ? max(0, min(current / total, 1)) : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: height)
                Capsule()
                    .fill(Color("Primary"))
                    .frame(width: width * CGFloat(progress), height: height)
                Circle()
                    .fill(Color.white)
                    .frame(width: height + 6.0, height: height + 6.0)
                    .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                    .offset(x: max(0, min(width - (height + 6.0), (width * CGFloat(progress)) - (height + 6.0) / 2.0)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedX = max(0, min(width, value.location.x))
                        let ratio = Double(clampedX) / Double(width)
                        let newSeconds = (total > 0) ? (ratio * total) : 0
                        current = newSeconds
                        onScrub(newSeconds)
                    }
            )
        }
        .frame(height: 18)
    }
}

#Preview {
    RecordView(audioURL: nil)
}
