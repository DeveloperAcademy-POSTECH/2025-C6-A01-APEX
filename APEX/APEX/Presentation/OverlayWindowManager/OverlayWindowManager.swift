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
    private var hostingController: UIHostingController<AnyView>?
    
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
        
        let contentView = AnyView(content())
        hostingController = UIHostingController(rootView: contentView)
        hostingController?.view.backgroundColor = .clear
        overlayWindow?.rootViewController = hostingController
    }
    
    func updateOverlay<Content: View>(@ViewBuilder content: () -> Content) {
        guard let hostingController = hostingController else { return }
        let contentView = AnyView(content())
        hostingController.rootView = contentView
    }
    
    func hideOverlay() {
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil
        hostingController = nil
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
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                // 주기적으로 오버레이 컨텐츠 업데이트 (바인딩 반영을 위해)
                if isPresented {
                    Task { @MainActor in
                        OverlayWindowManager.shared.updateOverlay {
                            overlayContent()
                        }
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
