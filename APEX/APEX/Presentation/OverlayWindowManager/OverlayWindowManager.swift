//
//  OverlayWindowManager.swift
//  APEX
//
//  Created for custom modals that need to appear above all UI elements
//

import SwiftUI
import UIKit
import Combine

@MainActor
class OverlayWindowManager: ObservableObject {
    static let shared = OverlayWindowManager()
    
    private var overlayWindow: UIWindow?
    
    private init() {}
    
    func showOverlay<Content: View>(@ViewBuilder content: () -> Content) {
        hideOverlay() // 기존 오버레이가 있으면 먼저 제거
        
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        
        overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow?.windowLevel = UIWindow.Level.alert + 1 // 시스템 UI보다 위에 표시
        overlayWindow?.backgroundColor = .clear
        overlayWindow?.isHidden = false
        
        let hostingController = UIHostingController(rootView: content())
        hostingController.view.backgroundColor = .clear
        overlayWindow?.rootViewController = hostingController
    }
    
    func hideOverlay() {
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil
    }
}

// SwiftUI에서 사용하기 쉽게 하는 View Modifier
struct WindowOverlayModifier<OverlayContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let overlayContent: () -> OverlayContent
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { oldValue, newValue in
                if newValue {
                    Task { @MainActor in
                        OverlayWindowManager.shared.showOverlay {
                            overlayContent()
                        }
                    }
                } else {
                    Task { @MainActor in
                        OverlayWindowManager.shared.hideOverlay()
                    }
                }
            }
    }
}

extension View {
    func windowOverlay<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(WindowOverlayModifier(isPresented: isPresented, overlayContent: content))
    }
}