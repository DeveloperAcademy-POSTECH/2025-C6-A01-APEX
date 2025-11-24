//
//  ShareTheme.swift
//  StashShare
//
//  Token colors for Share Extension when named assets are not included in the target.
//

import SwiftUI

private extension Color {
    init(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum ShareTheme {
    // Copied from app Assets.xcassets color tokens
    static let background = Color(hex: "FFFFFF")               // Background
    static let backgroundSecondary = Color(hex: "F2F2F5")      // BackgroundSecondary
    static let backgroundHover = Color(hex: "EBEBED")          // BackgroundHover
    static let primary = Color(hex: "2673E0")                  // Primary
    static let primaryContainer = Color(hex: "E9EDF5")         // PrimaryContainer
}


