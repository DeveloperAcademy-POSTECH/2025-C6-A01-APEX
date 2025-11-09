//
//  APEXMediaTile.swift
//  APEX
//
//  Created by AI Assistant on 11/08/25.
//

import SwiftUI
import AVFoundation

public enum MediaTileSource: Equatable {
	case image(Data)
	case video(URL)
}

public enum MediaTileVariant {
    case grid      // duration at bottom-left
    case single    // play button center, duration below the button
}

public struct APEXMediaTile: View {
	public let source: MediaTileSource
	public var showVideoIcon: Bool = true
    public var variant: MediaTileVariant = .grid
    public var showsDuration: Bool = true

	public init(source: MediaTileSource, showVideoIcon: Bool = true, variant: MediaTileVariant = .grid, showsDuration: Bool = true) {
		self.source = source
		self.showVideoIcon = showVideoIcon
        self.variant = variant
        self.showsDuration = showsDuration
	}

	@State private var thumb: UIImage?
	@State private var durationText: String = "00:00"

	public var body: some View {
		ZStack {
			switch source {
			case .image(let data):
				if let uiImage = UIImage(data: data) {
					Image(uiImage: uiImage)
						.resizable()
						.scaledToFill()
				} else {
					Rectangle().fill(Color.gray.opacity(0.15))
				}
			case .video(let url):
                if variant == .grid {
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let t = thumb {
                                Image(uiImage: t)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.15))
                            }
                        }
                        Color.black.opacity(0.4)
                            .allowsHitTesting(false)
                        if showsDuration {
                            Text(durationText)
                                .font(.caption1)
                                .foregroundStyle(.white)
                                .padding(12)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                .allowsHitTesting(false)
                        }
                    }
                } else {
                    ZStack {
                        Group {
                            if let t = thumb {
                                Image(uiImage: t)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.15))
                            }
                        }
                        .overlay(Color.black.opacity(0.4))
                        VStack(alignment: .center, spacing: 2) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color("Background"))
                                .shadow(radius: 4)
                            if showsDuration {
                                Text(durationText)
                                    .font(.caption1)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
			}
		}
        // Ensure tile content expands to any external frame applied by parent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
		.clipped()
		.task {
			if case .video(let url) = source, thumb == nil {
				thumb = generateThumbnail(for: url)
				durationText = format(durationOf: url)
			}
		}
	}
}

public struct APEXMediaSingleCard: View {
    public let source: MediaTileSource
    public let baseTileWidth: CGFloat
    public let columnsSpanned: Int
    public let spacing: CGFloat
    public var cornerRadius: CGFloat = 10

    @State private var thumb: UIImage?
    @State private var durationText: String = "00:00"

    public init(
        source: MediaTileSource,
        baseTileWidth: CGFloat,
        columnsSpanned: Int = 2,
        spacing: CGFloat = 2,
        cornerRadius: CGFloat = 10
    ) {
        self.source = source
        self.baseTileWidth = baseTileWidth
        self.columnsSpanned = max(1, columnsSpanned)
        self.spacing = spacing
        self.cornerRadius = cornerRadius
    }

    private var computedWidth: CGFloat {
        (baseTileWidth * CGFloat(columnsSpanned)) + (spacing * CGFloat(columnsSpanned - 1))
    }

    public var body: some View {
        switch source {
        case .image(let data):
            Group {
                if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 160)
                }
            }
            .frame(width: computedWidth)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(Rectangle())
        case .video(let url):
            VStack(alignment: .center, spacing: 8) {
                ZStack {
                    Rectangle()
                        .foregroundStyle(Color.black.opacity(0.15))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay {
                            if let thumb {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFill()
                            }
                        }
                        .overlay(Color.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                    VStack(alignment: .center, spacing: 2) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color("Background"))
                            .shadow(radius: 4)
                        Text(durationText)
                            .font(.caption1)
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: computedWidth)
            .contentShape(Rectangle())
            .onAppear {
                if thumb == nil {
                    thumb = generateThumbnail(for: url)
                    durationText = format(durationOf: url)
                }
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
	generator.maximumSize = CGSize(width: 600, height: 600)
	do {
		let cgImage = try generator.copyCGImage(at: .init(seconds: 0.1, preferredTimescale: 600), actualTime: nil)
		return UIImage(cgImage: cgImage)
	} catch {
		return nil
	}
}


