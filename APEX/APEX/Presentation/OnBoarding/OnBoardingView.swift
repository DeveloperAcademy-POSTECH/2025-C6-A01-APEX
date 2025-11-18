//
//  OnBoardingView.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import SwiftUI
import AuthenticationServices
import UIKit

struct OnBoardingView: View {
    let onComplete: (() -> Void)?
    let onGuest: (() -> Void)?
    @State private var signInCoordinator: AppleSignInCoordinator?
    @State private var showNamePrompt: Bool = false
    @State private var tempGivenName: String = ""
    @State private var tempFamilyName: String = ""
    @State private var pendingEmail: String? = nil
    @State private var showGuestAlert: Bool = false

    init(onComplete: (() -> Void)? = nil, onGuest: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onGuest = onGuest
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            header
            Spacer()
            bottomCTA
        }
        .background(Color("Background"))
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showNamePrompt) {
            VStack(spacing: 16) {
                Text("이름을 입력해 주세요")
                    .font(.title3)
                    .padding(.top, 12)
                TextField("이름", text: $tempGivenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                TextField("성(선택)", text: $tempFamilyName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button {
                    applyManualProfileUpdate(given: tempGivenName, family: tempFamilyName, email: pendingEmail)
                    showNamePrompt = false
                    onComplete?()
                } label: {
                    Text("저장")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color("Primary"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(tempGivenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("건너뛰기") {
                    applyManualProfileUpdate(given: tempGivenName, family: tempFamilyName, email: pendingEmail)
                    showNamePrompt = false
                    onComplete?()
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
            .padding(16)
            .presentationDetents([.height(280)])
        }
        .alert("게스트로 시작하시겠어요", isPresented: $showGuestAlert) {
            Button("아니오", role: .cancel) { }
            Button("네", role: .destructive) { onGuest?() }
        } message: {
            Text("앱을 삭제하거나 기기변경 시 앱 내 활동이 저장되지 않습니다.")
        }
    }

    private var header: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(Color("Primary"))
                .frame(height: 260)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Text("Stash에 오신 것을 환영해요")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text("고객별 메모를 빠르게 정리하고, 메모를 빠르게 찾을 수 있어.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: 12) {
            Button(action: { performAppleSignIn() }) {
                Text("Apple로 로그인")
                    .foregroundStyle(.white)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 20)
            .accessibilityIdentifier("onboarding.appleSignInButton")

            Button(action: { showGuestAlert = true }) {
                Text("게스트로 시작할게요")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color("GrayLabel"))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
 
private extension OnBoardingView {
    func performAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let coordinator = AppleSignInCoordinator(
            onSuccess: { credential in
                let given = credential.fullName?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let family = credential.fullName?.familyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let email = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines)

                if given.isEmpty && family.isEmpty {
                    let fallback = email.flatMap { $0.split(separator: "@").first.map(String.init) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    self.tempGivenName = fallback
                    self.tempFamilyName = ""
                    self.pendingEmail = email
                    self.showNamePrompt = true
                } else {
                    applyManualProfileUpdate(given: given, family: family, email: email)
                    onComplete?()
                }
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

#Preview {
    OnBoardingView(onComplete: {}, onGuest: {})
}

// MARK: - Apple Sign-In Coordinator
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    typealias Success = (ASAuthorizationAppleIDCredential) -> Void
    typealias Failure = (Error?) -> Void

    private let onSuccess: Success
    private let onFailure: Failure

    init(onSuccess: @escaping Success, onFailure: @escaping Failure) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            onSuccess(credential)
        } else {
            onFailure(nil)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onFailure(error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return window
        }
        return ASPresentationAnchor()
    }
}
