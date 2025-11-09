//
//  APEXFileTile.swift
//  APEX
//
//  Reusable file tile component matching chat view styling.
//
import SwiftUI
import UniformTypeIdentifiers
import UIKit

public struct APEXFileTile: View {
    public let url: URL
    public let contentType: UTType?
    public var highlightQuery: String?
    public var size: CGFloat
    public var onTap: (() -> Void)?

    public init(
        url: URL,
        contentType: UTType?,
        highlightQuery: String? = nil,
        size: CGFloat = 119,
        onTap: (() -> Void)? = nil
    ) {
        self.url = url
        self.contentType = contentType
        self.highlightQuery = highlightQuery
        self.size = size
        self.onTap = onTap
    }

    public var body: some View {
        ZStack {
            Color("BackgroundSecondary")
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: fileSystemSymbolName(for: contentType, url: url))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black)

                Spacer()

                if let attr = highlightedName() {
                    Text(attr)
                        .font(.caption2)
                        .lineLimit(4)
                        .truncationMode(.middle)
                        .foregroundStyle(.black)
                        .padding(.bottom, 4)
                } else {
                    Text(url.lastPathComponent)
                        .font(.caption2)
                        .lineLimit(4)
                        .truncationMode(.middle)
                        .foregroundStyle(.black)
                        .padding(.bottom, 4)
                }

                if let sizeText = fileSizeText(for: url) {
                    Text(sizeText)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }

            .padding(12)
        }
        .frame(width: size, height: size)
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            if let onTap {
                onTap()
            } else {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
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

private func fileSizeText(for url: URL) -> String? {
    if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) {
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    return nil
}

private extension APEXFileTile {
    func highlightedName() -> AttributedString? {
        guard let query = highlightQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else { return nil }
        let name = url.lastPathComponent
        let mas = NSMutableAttributedString(string: name)
        let nameNSString = name as NSString
        let fullRange = NSRange(location: 0, length: nameNSString.length)
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var searchRange = fullRange
        while true {
            let foundRange = nameNSString.range(of: query, options: options, range: searchRange)
            if foundRange.location == NSNotFound { break }
            mas.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.45), range: foundRange)
            let nextLocation = foundRange.location + foundRange.length
            if nextLocation >= nameNSString.length { break }
            searchRange = NSRange(location: nextLocation, length: nameNSString.length - nextLocation)
        }
        return AttributedString(mas)
    }
}


