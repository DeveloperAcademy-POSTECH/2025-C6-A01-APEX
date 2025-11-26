import SwiftUI
import UIKit

struct VideoThumbTile: View {
    let url: URL
    @State private var thumb: UIImage?
    @State private var duration: String = "00:00"

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .foregroundStyle(Color.gray.opacity(0.15))
                .frame(height: 124)
                .overlay {
                    if let thumb {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .overlay(Color.black.opacity(0.4))
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(duration)
                .font(.caption1)
                .foregroundStyle(.white)
                .padding(12)
        }
        .task {
            let urlCopy = url
            DispatchQueue.global(qos: .userInitiated).async {
                let generatedThumb: UIImage? = (self.thumb == nil) ? generateThumbnail(for: urlCopy) : nil
                let durationText = format(durationOf: urlCopy)
                DispatchQueue.main.async {
                    if self.thumb == nil { self.thumb = generatedThumb }
                    self.duration = durationText
                }
            }
        }
    }
}
