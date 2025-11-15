//
//  LinkPreviewSupport.swift
//  APEX
//
//  Created by AI Assistant on 11/08/25.
//

import SwiftUI
import LinkPresentation
import Combine
import UIKit

final class LinkPreviewLoader: ObservableObject {
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

struct LPImageFromProvider: View {
	let provider: NSItemProvider?
	@State private var image: UIImage?

	var body: some View {
		Group {
			if let image {
				Image(uiImage: image)
					.resizable()
					.interpolation(.high)
					.antialiased(true)
					.renderingMode(.original)
			} else {
				Color.gray.opacity(0.08)
			}
		}
		.task {
			guard image == nil, let provider else { return }
			_ = provider.loadObject(ofClass: UIImage.self) { obj, _ in
				if let img = obj as? UIImage {
					DispatchQueue.main.async { self.image = img }
				}
			}
		}
	}
}

// MARK: - Shared helpers

func normalizeURL(_ url: URL) -> URL {
	if let scheme = url.scheme, !scheme.isEmpty { return url }
	return URL(string: "https://" + url.absoluteString) ?? url
}

func subtitleText(from meta: LPLinkMetadata?, fallback: URL) -> String {
	let resolvedURL = meta?.url ?? meta?.originalURL ?? fallback
	var path = resolvedURL.path
	if path.hasPrefix("/") { path.removeFirst() }
	let query = resolvedURL.query.map { "?\($0)" } ?? ""
	let subtitle = path + query
	return subtitle.isEmpty ? resolvedURL.absoluteString : subtitle
}

// MARK: - Shared LinkPreviewCard

public struct LinkPreviewCard: View {
	let url: URL
	let width: CGFloat?
	@StateObject private var loader: LinkPreviewLoader

	public init(url: URL, width: CGFloat? = nil) {
		self.url = url
		self.width = width
		_loader = StateObject(wrappedValue: LinkPreviewLoader(url: normalizeURL(url)))
	}

	public var body: some View {
        let targetWidth = width ?? 246.0
        let imageHeight = 180.0
		Button {
			let target = normalizeURL(url)
			UIApplication.shared.open(target, options: [:], completionHandler: nil)
		} label: {
			VStack(spacing: 0) {
				Group {
					if let meta = loader.metadata, meta.imageProvider != nil {
						LPImageFromProvider(provider: meta.imageProvider)
							.scaledToFill()
					} else {
						Color.gray.opacity(0.08)
					}
				}
				.frame(width: targetWidth, height: imageHeight)
				.clipped()
				VStack(alignment: .leading, spacing: 0) {
					Image("URL")
						.padding(.bottom, 2)
                    Spacer(minLength: 0)
					Text(loader.metadata?.title ?? url.host ?? url.absoluteString)
						.font(.caption2)
						.lineLimit(2)
						.padding(.bottom, 4)
					Text(subtitleText(from: loader.metadata, fallback: url))
						.font(.caption2)
						.foregroundColor(.gray)
						.lineLimit(2)
				}
				.padding(.horizontal, 12)
				.padding(.bottom, 12)
				.padding(.top, 4)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.frame(width: targetWidth, alignment: .top)
			.background(Color("BackgroundSecondary"))
			.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
			.contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
		}
		.buttonStyle(.plain)
	}
}


