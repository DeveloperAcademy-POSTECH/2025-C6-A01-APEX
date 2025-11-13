//
//  APEXLinkTile.swift
//  APEX
//
//  Common link tile component per design.
//

import SwiftUI
import LinkPresentation
import Combine
import UIKit

public struct APEXLinkTile: View {
	public let url: URL
	public let width: CGFloat?
	@StateObject private var loader: LinkPreviewLoader

	public init(url: URL, width: CGFloat? = nil) {
		self.url = url
		self.width = width
		_loader = StateObject(wrappedValue: LinkPreviewLoader(url: normalizeURL(url)))
	}

	public var body: some View {
		let length = width ?? 124
		Button {
			let target = normalizeURL(url)
			UIApplication.shared.open(target, options: [:], completionHandler: nil)
		} label: {
			VStack(alignment: .leading) {
				// Host row
                Image("link")
                    .padding(.bottom, 8)
    
				
				// Title
				Text(loader.metadata?.title ?? url.absoluteString)
					.font(.caption2)
                    .foregroundStyle(Color("BlackLabel"))
					.lineLimit(1)
                    .padding(.bottom, 4)
				
				// Subtitle (path/query)
				Text(subtitleText(from: loader.metadata, fallback: url))
					.font(.caption2)
					.foregroundColor(Color("GrayLabel"))
					.lineLimit(4)
			}
			.padding(12)
            .frame(width: length, height: length, alignment: .leading)
			.background(Color("BackgroundSecondary"))
			.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
			.contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
		}
		.buttonStyle(.plain)
	}
}

#Preview("APEXLinkTile - Samples") {
	VStack(alignment: .leading, spacing: 16) {
		APEXLinkTile(url: URL(string: "https://www.apple.com")!)
		APEXLinkTile(url: URL(string: "https://github.com/apple/swift")!, width: 220)
	}
	.padding()
	.background(Color("Background"))
}
