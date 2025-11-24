//
//  ProfileExt.swift
//  StashShare
//
//  Copy of Profile view to match avatar visuals in the extension.
//

import SwiftUI

struct Profile: View {
    enum Size: Int {
        case extraSmall = 48
        case small = 100
        case large = 232
    }
    let image: UIImage?
    let initials: String
    let size: Size
    var fontSize: CGFloat?
    var backgroundColor: Color = ShareTheme.primaryContainer
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
                        .font(.system(size: fontSize ?? dynamicFontSize, weight: fontWeight))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
    }

    private var dynamicFontSize: CGFloat {
        let baseSize = side * 0.64
        if initials.count <= 1 {
            return baseSize
        } else if initials.count == 2 {
            return baseSize * 0.85
        } else {
            return baseSize * 0.7
        }
    }
    private var side: CGFloat { CGFloat(size.rawValue) }
}

extension Profile {
    static func makeInitials(name: String, surname: String) -> String {
        let givenName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let familyName = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        if givenName.isEmpty && familyName.isEmpty { return "" }
        if containsHangul(givenName) || containsHangul(familyName) {
            return String((familyName.isEmpty ? givenName : familyName).prefix(1))
        } else {
            let first = givenName.isEmpty ? "" : String(givenName.prefix(1)).uppercased()
            let last = familyName.isEmpty ? "" : String(familyName.prefix(1)).uppercased()
            return first + last
        }
    }

    private static func containsHangul(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let scalarValue = scalar.value
            if (0xAC00...0xD7A3).contains(scalarValue)
                || (0x1100...0x11FF).contains(scalarValue)
                || (0x3130...0x318F).contains(scalarValue) {
                return true
            }
        }
        return false
    }
}


