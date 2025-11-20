import SwiftUI
import AVFoundation
import UIKit

// Shared media helpers for Chatting subviews

func format(durationOf url: URL) -> String {
    let asset = AVAsset(url: url)
    let seconds = Int(CMTimeGetSeconds(asset.duration).rounded())
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

func generateThumbnail(for url: URL) -> UIImage? {
    let asset = AVAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1200, height: 1200)
    do {
        let cgImage = try generator.copyCGImage(at: .init(seconds: 0.1, preferredTimescale: 600), actualTime: nil)
        return UIImage(cgImage: cgImage)
    } catch {
        return nil
    }
}

func openFileURL(_ url: URL) {
    if FileManager.default.fileExists(atPath: url.path) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}


