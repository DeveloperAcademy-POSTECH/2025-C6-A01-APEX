//
//  Image+Ex.swift
//  APEX
//
//  Utility to convert SwiftUI Image into UIImage for asset uploads.
//

import SwiftUI
import UIKit

public extension Image {
    func asUIImage(targetSize: CGSize = CGSize(width: 1024, height: 1024)) -> UIImage? {
        let renderer = ImageRenderer(
            content: self
                .resizable()
                .scaledToFit()
                .frame(width: targetSize.width, height: targetSize.height)
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}



