import SwiftUI
import UniformTypeIdentifiers
import UIKit

public struct FileMemo: View {
    public let url: URL
    public let contentType: UTType?
    public var highlightQuery: String?
    public var width: CGFloat
    public var onTap: (() -> Void)?
    
    @State private var rightThumbnail: UIImage?
    
    public init(
        url: URL,
        contentType: UTType?,
        highlightQuery: String? = nil,
        width: CGFloat = 213,
        onTap: (() -> Void)? = nil
    ) {
        self.url = url
        self.contentType = contentType
        self.highlightQuery = highlightQuery
        self.width = width
        self.onTap = onTap
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                if let attr = highlightedName() {
                    Text(attr)
                        .font(.caption2)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .foregroundStyle(.black)
                } else {
                    Text(fullOrTruncatedName())
                        .font(.caption2)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .foregroundStyle(.black)
                }
                
                Spacer(minLength: 0)
                
                Image(iconName(for: contentType, url: url))
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }
            
            // Bottom: file size
            if let sizeText = fileSizeText(for: url) {
                Text(sizeText)
                    .font(.caption2)
                    .foregroundStyle(Color("GrayLabel"))
            }
        }
        .padding(12)
        .background(Color("BackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .frame(minWidth: width, maxWidth: width)
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
        .task {
            if isImageFile(contentType: contentType, url: url), rightThumbnail == nil {
                rightThumbnail = loadImageThumb(from: url, targetMaxLength: 600)
            }
        }
    }
}

// MARK: - Helpers

private func isImageFile(contentType: UTType?, url: URL) -> Bool {
    var resolvedType: UTType? = contentType
    if resolvedType == nil, !url.pathExtension.isEmpty {
        resolvedType = UTType(filenameExtension: url.pathExtension)
    }
    if let resolved = resolvedType, resolved.conforms(to: .image) {
        return true
    }
    return false
}

private func iconName(for type: UTType?, url: URL?) -> String {
    var resolvedType: UTType? = type
    if resolvedType == nil, let ext = url?.pathExtension, !ext.isEmpty {
        resolvedType = UTType(filenameExtension: ext)
    }
    guard let resolved = resolvedType else { return "Document2" }
    if resolved.conforms(to: .audio) { return "Sound2" }
    if resolved.conforms(to: .image) { return "Photo2" }
    if resolved.conforms(to: .movie) || resolved.conforms(to: .audiovisualContent) { return "Video2" }
    return "Document2"
}

private func loadImageThumb(from url: URL, targetMaxLength: CGFloat) -> UIImage? {
    guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
        return nil
    }
    let size = image.size
    let maxSide = max(size.width, size.height)
    guard maxSide > 0 else { return image }
    let scale = targetMaxLength / maxSide
    let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}

private func fileSizeText(for url: URL) -> String? {
    if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) {
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    return nil
}

private extension FileMemo {
    // Compute adaptive display name: show full if it fits within 3 lines; otherwise truncate middle keeping last 4 chars + extension.
    func fullOrTruncatedName() -> String {
        let full = url.lastPathComponent
        let available = availableTextWidth(containerWidth: width)
        if fitsInThreeLines(text: full, availableWidth: available) { return full }
        return truncatedFilename()
    }
    func truncatedFilename() -> String {
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        if baseName.count > 4 {
            let tail4 = String(baseName.suffix(4))
            let head = String(baseName.prefix(max(0, min(16, baseName.count - 4))))
            let extPart = ext.isEmpty ? "" : "." + ext
            return head + "..." + tail4 + extPart
        } else {
            return url.lastPathComponent
        }
    }
    func availableTextWidth(containerWidth: CGFloat) -> CGFloat {
        // container width - horizontal padding (12*2) - spacing (4) - trailing icon (40)
        return max(0, containerWidth - 24 - 4 - 40)
    }
    func fitsInThreeLines(text: String, availableWidth: CGFloat) -> Bool {
        let font = UIFont.preferredFont(forTextStyle: .caption2)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        let maxHeight = font.lineHeight * 3.0
        return bounds.height <= maxHeight + 0.5
    }
    
    // Highlight query (if provided) with yellow background and insert newline before extension.
    func highlightedName() -> AttributedString? {
        guard let query = highlightQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else { return nil }
        let formatted = fullOrTruncatedName()
        let mas = NSMutableAttributedString(string: formatted)
        let ns = formatted as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var searchRange = fullRange
        while true {
            let foundRange = ns.range(of: query, options: options, range: searchRange)
            if foundRange.location == NSNotFound { break }
            mas.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.45), range: foundRange)
            let nextLocation = foundRange.location + foundRange.length
            if nextLocation >= ns.length { break }
            searchRange = NSRange(location: nextLocation, length: ns.length - nextLocation)
        }
        return AttributedString(mas)
    }
}

#if DEBUG
struct FileMemo_Previews: PreviewProvider {
    static func tempPNGURL() -> URL {
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let rect = CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 16).fill()
        }
        let data = img.pngData() ?? Data()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Family_Photo_Summer_Vacation_2024_Sunset_At_The_Beach.png")
        try? data.write(to: url)
        return url
    }
    
    static var previews: some View {
        let longDoc = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Quarterly-Business-Review-Extremely-Long-Filename-To-Test-Middle-Ellipsis-And-Extension.pdf")
        let photo = tempPNGURL()
        let video = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Company_Event_Highlights_2024_Version_Final_Export.mp4")
        let audio = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Interview_Recording_With_Client_Part01_VeryLongName.m4a")
        
        return Group {
            VStack(alignment: .leading, spacing: 12) {
                Text("Long Names & 3-line cap").font(.headline)
                FileMemo(
                    url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("This_is_an_example_of_a_very_very_very_long_filename_that_should_truncate_in_the_middle_and_keep_the_last_four_chars_of_the_basename_before_extension.pptx"),
                    contentType: UTType(filenameExtension: "pptx"),
                    highlightQuery: "very",
                    width: 213
                )
                FileMemo(
                    url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Another_Sample_File_Name_With_Somewhat_Long_Basename_Before_Extension_numbers1234.xlsx"),
                    contentType: UTType(filenameExtension: "xlsx"),
                    highlightQuery: "File",
                    width: 213
                )
            }
            .padding()
            .previewDisplayName("Long text cases")
        }
        .background(Color("Primary"))
    }
}
#endif


