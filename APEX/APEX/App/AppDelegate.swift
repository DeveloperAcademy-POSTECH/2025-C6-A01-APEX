//
//  AppDelegate.swift
//  APEX
//
//  Created by APEX CloudKit integration.
//

import UIKit
import UserNotifications
import CloudKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Intentionally do not request push here.
        // We defer CloudKit/push setup until after onboarding when user is not in guest mode.
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        return true
    }

    /// Call this after onboarding completes for non-guest users to set up CloudKit and push.
    func startCloudKitAndPushSetupIfNeeded(_ application: UIApplication = UIApplication.shared) {
        let isGuest = UserDefaults.standard.bool(forKey: "apex.isGuestMode")
        guard !isGuest else { return }
        CloudKitManager.shared.container.accountStatus { status, _ in
            guard status == .available else {
                print("[CloudKit] Account not available; skipping subscription and push setup")
                return
            }
            CloudKitManager.shared.ensureDatabaseSubscription()
            UNUserNotificationCenter.current().delegate = self
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Nothing to do: CloudKit + APNs token is managed by the system.
        print("[Push] Registered for remote notifications")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] Failed to register: \(error)")
    }

    // CloudKit silent push handler (foreground/background)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        CloudKitManager.shared.handleRemoteNotification(userInfo, completion: completionHandler)
    }

    // Background Fetch fallback: periodically ask CloudKit for changes to keep local state fresh
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Only attempt when not guest and iCloud available
        let isGuest = UserDefaults.standard.bool(forKey: "apex.isGuestMode")
        guard !isGuest else { completionHandler(.noData); return }
        CloudKitManager.shared.container.accountStatus { status, _ in
            guard status == .available else { completionHandler(.noData); return }
            CloudKitManager.shared.fetchDatabaseChanges(completion: completionHandler)
        }
    }
}


