//
//  APEXApp.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI

@main
struct APEXApp: App {
    var body: some Scene {
        WindowGroup {
                        RootView()
                .border(.yellow, width: 5.0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
    }
}
