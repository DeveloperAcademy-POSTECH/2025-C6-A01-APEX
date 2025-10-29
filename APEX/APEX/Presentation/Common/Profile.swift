//
//  AvatarView.swift
//  APEX
//
//  Created by AI Assistant on 10/29/25.
//

import SwiftUI

struct Profile: View {
    let image: UIImage?
    let initials: String
    let size: CGFloat
    var fontSize: CGFloat?
    var backgroundColor: Color = Color("PrimaryContainer")
    var textColor: Color = .white
    var fontWeight: Font.Weight = .semibold

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                    Text(initials)
                        .font(.system(size: fontSize ?? defaultFontSize, weight: fontWeight))
                        .foregroundColor(textColor)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var defaultFontSize: CGFloat { size * 0.64 }
}
#Preview {
    VStack(spacing: 16) {
        Profile(image: nil, initials: "GK", size: 48)
        Profile(image: nil, initials: "김", size: 48)
        Profile(image: nil, initials: "G", size: 100, fontSize: 64)
    }
}
