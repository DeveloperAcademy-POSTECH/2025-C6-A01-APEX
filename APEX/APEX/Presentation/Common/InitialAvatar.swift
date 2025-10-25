//
//  InitialAvatar.swift
//  APEX
//
//  Created by 조운경 on 10/24/25.
//

import SwiftUI

// MARK: - Placeholder Avatar
struct InitialAvatar: View {
    let letter: String
    let size: CGFloat
    let fontSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color("PrimaryContainer"))
            Text(letter)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    InitialAvatar(letter: "G", size: 48, fontSize: 30.72)
}
