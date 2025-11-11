//
//  Color+Ex.swift
//  APEX
//
//  Created by 조운경 on 11/11/25.
//

import Foundation
import SwiftUI

extension Color {
    static func RGB(_ r: Int, _ g: Int, _ b: Int, opacity: Double = 1.0) -> Color {
        Color(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: opacity
        )
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Figma spec: hover background RGB(0.952, 0.952, 0.96)
    static var hoverBackground: Color {
        Color(
            .sRGB,
            red: 0.952,
            green: 0.952,
            blue: 0.96,
            opacity: 1.0
        )
    }
}
