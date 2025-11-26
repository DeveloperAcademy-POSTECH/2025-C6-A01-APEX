import UIKit

// Normalize UIImage into standard 8-bit sRGB BGRA by redrawing via UIGraphicsImageRenderer.
// Keeps alpha when opaque == false.
func normalizeUIImageToSRGB8(_ image: UIImage, opaque: Bool = false) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = image.scale
    format.opaque = opaque
    if #available(iOS 12.0, *) {
        format.preferredRange = .standard
    }
    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: image.size))
    }
}


