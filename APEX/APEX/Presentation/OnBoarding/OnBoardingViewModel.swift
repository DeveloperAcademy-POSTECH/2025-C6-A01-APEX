//
//  OnBoardingViewModel.swift
//  APEX
//
//  Created by Assistant on 11/23/25.
//

import Foundation
import Combine
import SwiftUI
import AuthenticationServices
import UIKit

@MainActor
final class OnBoardingViewModel: ViewModelable {
    enum Action {
        case appleSignInTapped
        case guestTapped
        case confirmGuest
        case namePromptSave
        case namePromptSkip
    }
    
    // MARK: - Outputs (bound to View)
    @Published var showNamePrompt: Bool = false
    @Published var tempGivenName: String = ""
    @Published var tempFamilyName: String = ""
    @Published var pendingEmail: String? = nil
    @Published var showGuestAlert: Bool = false
    
    // MARK: - Navigation callbacks
    private let onComplete: (() -> Void)?
    private let onGuest: (() -> Void)?
    
    // MARK: - Internals
    private var namePromptNext: (() -> Void)? = nil
    private var signInCoordinator: AppleSignInCoordinator?
    
    init(onComplete: (() -> Void)? = nil, onGuest: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onGuest = onGuest
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .appleSignInTapped:
            performAppleSignIn()
            
        case .guestTapped:
            showGuestAlert = true
            
        case .confirmGuest:
            // 게스트 흐름에서만 이름 입력 시트를 보여줍니다.
            pendingEmail = nil
            tempGivenName = ""
            tempFamilyName = ""
            namePromptNext = { [weak self] in self?.onGuest?() }
            showNamePrompt = true
            
        case .namePromptSave:
            applyManualProfileUpdate(given: tempGivenName, family: tempFamilyName, email: pendingEmail)
            showNamePrompt = false
            let next = namePromptNext
            namePromptNext = nil
            next?()
            
        case .namePromptSkip:
            applyManualProfileUpdate(given: tempGivenName, family: tempFamilyName, email: pendingEmail)
            showNamePrompt = false
            let next = namePromptNext
            namePromptNext = nil
            next?()
        }
    }
}

// MARK: - Private helpers
private extension OnBoardingViewModel {
    func persistAppleName(given: String, family: String) {
        let defaults = UserDefaults.standard
        defaults.set(given, forKey: "apple.fullName.given")
        defaults.set(family, forKey: "apple.fullName.family")
    }
    
    func loadSavedAppleName() -> (given: String, family: String)? {
        let defaults = UserDefaults.standard
        guard
            let givenName = defaults.string(forKey: "apple.fullName.given"),
            let familyName = defaults.string(forKey: "apple.fullName.family"),
            (!givenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
             || !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        else {
            return nil
        }
        return (givenName, familyName)
    }
    
    func performAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let coordinator = AppleSignInCoordinator(
            onSuccess: { [weak self] credential in
                guard let self else { return }
                let rawGiven = credential.fullName?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let rawFamily = credential.fullName?.familyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let email = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 1) 이름이 내려오면 저장 후 바로 완료
                if !rawGiven.isEmpty || !rawFamily.isEmpty {
                    persistAppleName(given: rawGiven, family: rawFamily)
                    applyManualProfileUpdate(given: rawGiven, family: rawFamily, email: email)
                    onComplete?()
                    return
                }
                
                // 2) 캐시에 이름이 있으면 사용 후 완료
                if let cached = loadSavedAppleName() {
                    applyManualProfileUpdate(given: cached.given, family: cached.family, email: email)
                    onComplete?()
                    return
                }
                
                // 3) 이름이 전혀 없으면 게스트 모드와 동일한 입력 시트를 띄운 뒤 완료
                pendingEmail = email
                tempGivenName = ""
                tempFamilyName = ""
                namePromptNext = { [weak self] in self?.onComplete?() }
                showNamePrompt = true
            },
            onFailure: { _ in }
        )
        signInCoordinator = coordinator
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
    }
    
    func applyManualProfileUpdate(given: String, family: String, email: String?) {
        let store = ClientsStore.shared
        let trimmedGiven = given.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFamily = family.trimmingCharacters(in: .whitespacesAndNewlines)
        if store.clients.isEmpty {
            let newMe = Client(
                profile: nil,
                nameCardFront: nil,
                nameCardBack: nil,
                surname: trimmedFamily,
                name: trimmedGiven.isEmpty ? "사용자" : trimmedGiven,
                position: nil,
                company: "",
                email: email,
                phoneNumber: nil,
                linkedinURL: nil,
                memo: nil,
                action: nil,
                favorite: false,
                pin: false,
                notes: []
            )
            store.add(newMe, atTop: true)
            // Trigger CloudKit AppUser sync immediately after onboarding
            store.update(newMe)
        } else {
            let me = store.clients[0]
            let updated = Client(
                id: me.id,
                profile: nil,
                nameCardFront: nil,
                nameCardBack: nil,
                surname: trimmedFamily.isEmpty ? me.surname : trimmedFamily,
                name: trimmedGiven.isEmpty ? (me.name.isEmpty ? "사용자" : me.name) : trimmedGiven,
                position: nil,
                company: "",
                email: email ?? me.email,
                phoneNumber: me.phoneNumber,
                linkedinURL: nil,
                memo: nil,
                action: me.action,
                favorite: me.favorite,
                pin: me.pin,
                notes: me.notes
            )
            store.update(updated)
        }
    }
}


