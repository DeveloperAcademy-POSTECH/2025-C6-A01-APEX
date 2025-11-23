//
//  UnsubscribeViewModel.swift
//  APEX
//
//  Created by Assistant on 11/23/25.
//

import Foundation
import Combine

@MainActor
final class UnsubscribeViewModel: ViewModelable {
    enum Action {
        case toggleAgree
        case tapUnsubscribe
    }
    
    // MARK: - UI State
    @Published var agreed: Bool = false
    @Published var isProcessing: Bool = false
    @Published var shouldDismiss: Bool = false
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .toggleAgree:
            agreed.toggle()
        case .tapUnsubscribe:
            performUnsubscribe()
        }
    }
}

// MARK: - Private
private extension UnsubscribeViewModel {
    func performUnsubscribe() {
        guard agreed, !isProcessing else { return }
        isProcessing = true
        CloudKitWipeService.shared.wipeAllUserCloudKitData { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    print("[Unsubscribe] CloudKit wipe failed: \(error)")
                }
                // 1) Clear persisted data
                LocalStore.shared.clearClients()
                ChatStore.shared.clear()
                ClientsStore.shared.resetToInitial()
                // Optionally clear app-specific preferences
                UserDefaults.standard.removeObject(forKey: "apex.notes.enabledCompanies")
                UserDefaults.standard.removeObject(forKey: "apex.notes.companyOrder")
                // 2) Reset onboarding state
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                // 3) Request app to present onboarding immediately
                NotificationCenter.default.post(name: .apexRequestOnboarding, object: nil)
                // 4) Dismiss current view
                self.isProcessing = false
                self.shouldDismiss = true
            }
        }
    }
}


