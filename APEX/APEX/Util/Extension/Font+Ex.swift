//
//  Font+Ex.swift
//  APEX
//
//  Created by 조운경 on 10/10/25.
//

import SwiftUI

extension Font {
    enum PretendardWeight {
        case regular
        case medium
        case semibold
        case bold
        
        var fontName: String {
            switch self {
            case .regular:
                return "PretandardVariable-Regular"
            case .medium:
                return "PretandardVariable-Medium"
            case .semibold:
                return "PretandardVariable-SemiBold"
            case .bold:
                return "PretandardVariable-Bold"
            }
        }
    }
    
    static func pretandard(_ weight: PretendardWeight, size: CGFloat) -> Font {
        return .custom(weight.fontName, size: size)
    }
    
    static var title1: Font { .pretandard(.semibold, size: 24) }
    static var title2: Font { .pretandard(.medium, size: 24) }
    static var title3: Font { .pretandard(.semibold, size: 20) }
    static var title4: Font { .pretandard(.medium, size: 20) }
    static var title5: Font { .pretandard(.semibold, size: 18) }
    static var title6: Font { .pretandard(.medium, size: 18) }
    static var body1: Font { .pretandard(.semibold, size: 16) }
    static var body2: Font { .pretandard(.medium, size: 16) }
    static var body3: Font { .pretandard(.regular, size: 16) }
    static var body4: Font { .pretandard(.semibold, size: 14) }
    static var body5: Font { .pretandard(.medium, size: 14) }
    static var body6: Font { .pretandard(.regular, size: 14) }
    static var caption1: Font { .pretandard(.semibold, size: 13) }
    static var caption2: Font { .pretandard(.medium, size: 13) }
}
