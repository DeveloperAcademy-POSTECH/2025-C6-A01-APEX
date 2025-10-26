//
//  MyProfilePrimaryActionView.swift
//  APEX
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

struct MyProfilePrimaryActionView: View {
    let title: String
    var action: () -> Void

    var body: some View {
        APEXButton(title, action: action)
            .apexButtonTheme(
                .init(
                    font: .title4,
                    foregroundEnabled: .white,
                    foregroundDisabled: .white.opacity(0.6),
                    backgroundEnabled: Color("Primary"),
                    backgroundPressed: Color("PrimaryHover"),
                    backgroundDisabled: Color("BackgroundDisabled"),
                    cornerRadius: 8,
                    height: 56,
                    horizontalPadding: 0
                )
            )
    }
}

#Preview {
    MyProfilePrimaryActionView(title: "메모하기") { }
        .padding()
        .background(Color("Background"))
}

