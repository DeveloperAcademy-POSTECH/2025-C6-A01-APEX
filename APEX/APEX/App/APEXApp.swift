//
//  APEXApp.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI
import UIKit

@main
struct APEXApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = NavigationRouter() // router instance for navigation
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("apex.isGuestMode") private var isGuestMode: Bool = false
    @AppStorage("appGroupMigration_v1") private var didMigrateToAppGroup: Bool = false
    private var isPreviewEnv: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1" || env["XCODE_RUNNING_FOR_PREVIEWS"] == "1" // preview flags
    }

    var body: some Scene {
        WindowGroup {
//            ChattingView()
//                .task {
//                    guard !isPreviewEnv else { return }
//                    // 앱 시작 후 1회: 권한 선요청 → 프리웜
//                    await CameraManager.shared.preAuthorize()
//                    CameraManager.shared.prewarmIfPossible()
//                }
//                .onChange(of: scenePhase) { phase in
//                    guard !isPreviewEnv else { return }
//                    // 포그라운드 복귀 시 짧게 다시 프리웜 (선택)
//                    if phase == .active {
//                        CameraManager.shared.prewarmIfPossible()
//                    }
//                }
            if hasCompletedOnboarding {
                RootView()
                    .environmentObject(router)
                    .task {
                        guard !isPreviewEnv else { return }
                        // After onboarding completion, if not guest, start CloudKit + push setup now.
                        if !isGuestMode {
                            appDelegate.startCloudKitAndPushSetupIfNeeded()
                            // Light refresh to avoid heavy note prefetch during startup
                            DispatchQueue.main.async {
                                ClientsStore.shared.forceLightCloudKitRefresh()
                            }
                        }
                        if !didMigrateToAppGroup {
                            migrateDocumentsToAppGroupIfNeeded()
                            didMigrateToAppGroup = true
                        }
                    }
                    .onOpenURL { url in
                        guard url.scheme?.lowercased() == "apex" else { return }
                        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
                        let dest = components.queryItems?.first(where: { $0.name == "dest" })?.value?.lowercased()
                        if dest == "notes" {
                            NotificationCenter.default.post(name: .apexSelectNotes, object: nil)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .apexRequestOnboarding)) { _ in
                        hasCompletedOnboarding = false
                        router.path = []
                    }
            } else {
                OnBoardingView(
                    onComplete: {
                        isGuestMode = false
                        hasCompletedOnboarding = true
                    },
                    onGuest: {
                        // Guest should persist across restarts like a completed onboarding
                        isGuestMode = true
                        hasCompletedOnboarding = true
                    }
                )
                .task {
                    guard !isPreviewEnv else { return }
                    if !didMigrateToAppGroup {
                        migrateDocumentsToAppGroupIfNeeded()
                        didMigrateToAppGroup = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .apexRequestOnboarding)) { _ in
                    hasCompletedOnboarding = false
                    router.path = []
                }
            }
        }
    }
}

// MARK: - One-time migration to App Group container
private extension APEXApp {
    func migrateDocumentsToAppGroupIfNeeded() {
        let fileManager = FileManager.default
        guard let appGroupBase = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.apex.StashShareExtension"),
              let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let folders = ["SharedVideos", "SharedFiles", "SharedAudios"]
        for folder in folders {
            let sourceDir = documents.appendingPathComponent(folder, isDirectory: true)
            let destDir = appGroupBase.appendingPathComponent(folder, isDirectory: true)
            guard fileManager.fileExists(atPath: sourceDir.path) else { continue }
            if !fileManager.fileExists(atPath: destDir.path) {
                try? fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
            }
            if let items = try? fileManager.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil) {
                for src in items {
                    var dest = destDir.appendingPathComponent(src.lastPathComponent)
                    let name = src.deletingPathExtension().lastPathComponent
                    let ext = src.pathExtension
                    var counter = 2
                    while fileManager.fileExists(atPath: dest.path) {
                        dest = destDir.appendingPathComponent("\(name) \(counter)").appendingPathExtension(ext)
                        counter += 1
                    }
                    do {
                        try fileManager.moveItem(at: src, to: dest)
                    } catch {
                        // Fallback: try copy then remove
                        if (try? fileManager.copyItem(at: src, to: dest)) != nil {
                            try? fileManager.removeItem(at: src)
                        }
                    }
                }
            }
            // Optionally remove empty source directory
            if let remaining = try? fileManager.contentsOfDirectory(atPath: sourceDir.path), remaining.isEmpty {
                try? fileManager.removeItem(at: sourceDir)
            }
        }
    }
}

// MARK: - App-wide Notifications
extension Notification.Name {
    static let apexRequestOnboarding = Notification.Name("apex.requestOnboarding")
    static let apexSelectNotes = Notification.Name("apex.selectNotes")
    static let apexSelectContacts = Notification.Name("apex.selectContacts")
}
