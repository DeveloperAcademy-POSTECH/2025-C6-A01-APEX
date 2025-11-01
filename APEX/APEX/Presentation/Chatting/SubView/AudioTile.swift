//
//  AudioTile.swift
//  APEX
//
//  Shared audio square tile and waveform shapes
//

import SwiftUI
import Combine
import AVFoundation

struct AudioSquareTile: View {
    let url: URL
    let duration: TimeInterval?
    var preferredLength: CGFloat?
    var titleOverride: String? = nil

    @State private var isPlaying: Bool = false
    @State private var player: AVAudioPlayer?
    @State private var durationText: String = "--:--"
    @State private var stopWork: DispatchWorkItem?
    @State private var phase: CGFloat = 0
    @State private var level: CGFloat = 0
    @State private var showWaveform: Bool = false
    @State private var inactivityWork: DispatchWorkItem?
    private let inactivityTimeout: TimeInterval = 3.0
    private let waveTimer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            if isPlaying { stopPlayback() } else { startPlayback() }
        } label: {
            ZStack {
                if showWaveform {
                    ScrollingWaveformFill(level: level, phase: phase, bgColor: Color("Primary"), strokeColor: .white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.black)
                        Spacer(minLength: 0)
                        Text(titleOverride ?? titleText())
                            .font(.caption2)
                            .lineLimit(1)
                            .padding(.bottom, 4)
                        Text(durationText)
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
                }

                if showWaveform {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color("Background"))
                        .shadow(radius: 4)
                        .allowsHitTesting(false)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(width: preferredLength ?? 116.33, height: preferredLength ?? 116.33)
            .background(Color("BackgroundSecondary"))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .onReceive(waveTimer) { _ in
            guard isPlaying, let audioPlayer = player else { return }
            audioPlayer.updateMeters()
            let power = audioPlayer.averagePower(forChannel: 0)
            let normalized = max(0.0, min(1.0, pow(10.0, Double(power) / 20.0)))
            level = CGFloat(normalized)
            let waveSpeed: CGFloat = 0.8
            phase = -2.0 * CGFloat.pi * waveSpeed * CGFloat(audioPlayer.currentTime)
        }
        .onAppear { updateDuration() }
        .onReceive(NotificationCenter.default.publisher(for: .apexStopAllAudioPlayback)) { _ in
            stopWork?.cancel(); inactivityWork?.cancel()
            player?.pause()
            isPlaying = false
            showWaveform = false
            phase = 0
            level = 0
        }
        .onDisappear {
            inactivityWork?.cancel(); inactivityWork = nil
            stopPlayback()
        }
    }

    private func updateDuration() {
        if let duration, duration > 0 {
            durationText = formatDuration(duration)
            return
        }
        if let tmp = try? AVAudioPlayer(contentsOf: url) {
            durationText = formatDuration(tmp.duration)
            return
        }
        let asset = AVAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        if seconds.isFinite && seconds > 0 { durationText = formatDuration(seconds) } else { durationText = "--:--" }
    }

    private func startPlayback() {
        do {
            inactivityWork?.cancel(); inactivityWork = nil
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.defaultToSpeaker])
            try? session.setActive(true)
            if player == nil { player = try AVAudioPlayer(contentsOf: url) }
            player?.isMeteringEnabled = true
            player?.prepareToPlay()
            player?.play()
            showWaveform = true
            isPlaying = true
            scheduleStopObserver()
        } catch {
            isPlaying = false
        }
    }

    private func stopPlayback() {
        stopWork?.cancel(); stopWork = nil
        player?.pause()
        isPlaying = false
        scheduleInactivityRevert()
    }

    private func scheduleStopObserver() {
        stopWork?.cancel()
        guard let player else { return }
        let remaining = max(0, player.duration - player.currentTime)
        let work = DispatchWorkItem {
            self.isPlaying = false
            self.showWaveform = false
            self.phase = 0
            self.level = 0
        }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
    }

    private func scheduleInactivityRevert() {
        inactivityWork?.cancel()
        let work = DispatchWorkItem {
            guard !isPlaying else { return }
            self.showWaveform = false
            self.phase = 0
            self.level = 0
        }
        inactivityWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + inactivityTimeout, execute: work)
    }

    private func titleText() -> String {
        let base = url.deletingPathExtension().lastPathComponent
        return base.isEmpty ? "음성 메모" : base
    }

    private func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration else { return "--:--" }
        let total = Int(duration.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ScrollingWaveformFill: View {
    var level: CGFloat
    var phase: CGFloat
    var bgColor: Color
    var strokeColor: Color

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let baseAmplitude = max(6, height * 0.15)
            let amplitude = baseAmplitude + height * 0.35 * level

            ZStack {
                bgColor
                PlaybackSineShape(amplitude: amplitude, phase: phase, frequency: 1.6)
                    .stroke(
                        strokeColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }
}

struct PlaybackSineShape: Shape {
    var amplitude: CGFloat
    var phase: CGFloat
    var frequency: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let width = rect.width
        let step: CGFloat = 2
        var posX: CGFloat = 0
        var first = true
        while posX <= width {
            let ratio = posX / width
            let angle = ratio * frequency * .pi * 2 + phase
            let posY = midY + sin(angle) * amplitude
            if first {
                path.move(to: CGPoint(x: posX, y: posY))
                first = false
            } else {
                path.addLine(to: CGPoint(x: posX, y: posY))
            }
            posX += step
        }
        return path
    }
}

