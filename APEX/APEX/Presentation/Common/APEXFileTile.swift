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
        size: CGFloat = 124,
        onTap: (() -> Void)? = nil
    ) {
        self.url = url
        self.contentType = contentType
        self.highlightQuery = highlightQuery
        self.size = size
        self.onTap = onTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(fileSystemSymbolName(for: contentType, url: url))
                .scaledToFit()
                .frame(width: 24, height: 24)

            if let attr = highlightedName() {
                Text(attr)
                    .font(.caption2)
                    .lineLimit(4)
                    .truncationMode(.middle)
                    .foregroundStyle(Color("BlackLabel"))
            } else {
                Text(displayNameWithNewline())
                    .font(.caption2)
                    .lineLimit(4)
                    .truncationMode(.middle)
                    .foregroundStyle(Color("BlackLabel"))
            }

            if let sizeText = fileSizeText(for: url) {
                Text(sizeText)
                    .font(.caption2)
                    .foregroundStyle(Color("GrayLabel"))
            }
        }
        .padding(12)
        .frame(width: size, height: size, alignment: .topLeading)
        .background(Color("BackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if let onTap {
                onTap()
            } else {
                if FileManager.default.fileExists(atPath: url.path) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }
    }
}

private func fileSystemSymbolName(for type: UTType?, url: URL?) -> String {
    var resolvedType: UTType? = type
    if resolvedType == nil, let ext = url?.pathExtension, !ext.isEmpty {
        resolvedType = UTType(filenameExtension: ext)
    }
    guard let resolved = resolvedType else { return "document2" }
    if resolved.conforms(to: .image) { return "photo2" }
    if resolved.conforms(to: .movie) || resolved.conforms(to: .audiovisualContent) { return "video2" }
    return "document2"
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
        // Insert a newline before the extension so that the extension appears on a new line.
        // Only apply when there is a valid extension and the dot is not the first character (to avoid hidden files like ".gitignore").
        if !url.pathExtension.isEmpty {
            let dotRange = nameNSString.range(of: ".", options: .backwards)
            if dotRange.location != NSNotFound && dotRange.location > 0 && dotRange.location < nameNSString.length {
                mas.insert(NSAttributedString(string: "\n"), at: dotRange.location)
            }
        }
        return AttributedString(mas)
    }

    func displayNameWithNewline() -> String {
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        guard !ext.isEmpty else { return url.lastPathComponent }
        return baseName + "\n." + ext
    }
}


