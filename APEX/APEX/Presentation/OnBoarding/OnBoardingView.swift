//
//  OnBoardingView.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import SwiftUI
import AuthenticationServices

struct OnBoardingView: View {
    let onComplete: (() -> Void)?

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
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
    }

    private var header: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("Background").opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 8)

                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Color("Primary"))
            }
            .frame(height: 260)
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Text("APEX에 오신 것을 환영해요")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text("고객과의 대화를 정리하고, 노트를 빠르게 찾을 수 있어요.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn, onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            }, onCompletion: { _ in
                onComplete?()
            })
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)
            .accessibilityIdentifier("onboarding.appleSignInButton")
            .overlay(
                Text("Apple로 로그인")
                    .foregroundStyle(.white)
                    .font(.system(size: 17, weight: .semibold))
                    .allowsHitTesting(false)
            )

            Button(action: { onComplete?() }, label: {
                Text("게스트로 시작할게요")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color("Primary"))
            })
            .buttonStyle(.plain)
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

#Preview {
    OnBoardingView(onComplete: {})
}
