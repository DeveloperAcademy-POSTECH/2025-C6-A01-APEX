//
//  APEXApp.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI

@main
struct APEXApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContactsView()
                .task {
                    // 앱 시작 후 1회: 권한 선요청 → 프리웜
                    await CameraManager.shared.preAuthorize()
                    CameraManager.shared.prewarmIfPossible()
                }
                .onChange(of: scenePhase) { phase in
                    // 포그라운드 복귀 시 짧게 다시 프리웜 (선택)
                    if phase == .active {
                        CameraManager.shared.prewarmIfPossible()
                    }
                }
        }
    }
}
