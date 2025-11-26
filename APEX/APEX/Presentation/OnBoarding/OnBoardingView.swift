//
//  OnBoardingView.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import SwiftUI
import UIKit

struct OnBoardingView: View {
    @StateObject private var viewModel: OnBoardingViewModel

    init(onComplete: (() -> Void)? = nil, onGuest: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: OnBoardingViewModel(onComplete: onComplete, onGuest: onGuest))
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
        .sheet(isPresented: $viewModel.showNamePrompt) {
            VStack(spacing: 16) {
                Text("이름을 입력해 주세요")
                    .font(.title3)
                    .padding(.top, 12)
                TextField("이름", text: $viewModel.tempGivenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                TextField("성(선택)", text: $viewModel.tempFamilyName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button {
                    viewModel.send(.namePromptSave)
                } label: {
                    Text("저장")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color("Primary"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(viewModel.tempGivenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .presentationDetents([.height(280)])
        }
        .alert(
            "게스트로 시작하시겠어요",
            isPresented: $viewModel.showGuestAlert,
            actions: {
                Button("아니오", role: .cancel) { }
                Button("네", role: .destructive) {
                    viewModel.send(.confirmGuest)
                }
            },
            message: {
                Text("앱을 삭제하거나 기기변경 시 앱 내 활동이 저장되지 않습니다.")
            }
        )
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
            Button(action: { viewModel.send(.appleSignInTapped) }) {
                Text("Apple로 로그인")
                    .foregroundStyle(.white)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 20)
            .accessibilityIdentifier("onboarding.appleSignInButton")

            Button(action: { viewModel.send(.guestTapped) }) {
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
