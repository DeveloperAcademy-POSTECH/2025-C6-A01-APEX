//
//  ApexSwipeBackModifier.swift
//  APEX
//
//  Created by AI Assistant on 11/14/25.
//

import SwiftUI

// MARK: - Environment flag to disable global swipe-back when needed
private struct ApexGlobalSwipeBackDisabledKey: EnvironmentKey {
	static let defaultValue: Bool = false
}

extension EnvironmentValues {
	var apexGlobalSwipeBackDisabled: Bool {
		get { self[ApexGlobalSwipeBackDisabledKey.self] }
		set { self[ApexGlobalSwipeBackDisabledKey.self] = newValue }
	}
}

extension View {
	/// Disable the globally applied swipe-back pop gesture for this view subtree.
	func apexSwipeBackDisabled(_ disabled: Bool) -> some View {
		environment(\.apexGlobalSwipeBackDisabled, disabled)
	}
}

// MARK: - Global swipe-back modifier
private struct ApexSwipeBackModifier: ViewModifier {
	@EnvironmentObject private var router: NavigationRouter
	@Environment(\.apexGlobalSwipeBackDisabled) private var isDisabled
	
	func body(content: Content) -> some View {
		content
			.simultaneousGesture(
				DragGesture(minimumDistance: 20)
					.onEnded { value in
						guard !isDisabled && !ApexSwipeBackState.shared.isDisabled else { return }
						let dx = value.translation.width
						let dy = value.translation.height
						guard abs(dx) > abs(dy) else { return }
						guard dx > 80 else { return }
						guard !router.path.isEmpty else { return }
                        // Special-case: if current is .chat and previous is profile, return to Contacts
                        let path = router.path
                        if let current = path.last {
                            switch current {
                            case .chat:
                                if path.count >= 2 {
                                    let previous = path[path.count - 2]
                                    switch previous {
                                    case .myProfile, .profileDetail:
                                        NotificationCenter.default.post(name: .apexSelectContacts, object: nil)
                                        router.popToRoot()
                                        return
                                    default:
                                        break
                                    }
                                }
                                router.pop()
                            default:
                                router.pop()
                            }
                        } else {
                            router.pop()
                        }
					}
			)
	}
}

extension View {
	/// Enables a global right-swipe gesture to pop the current navigation destination.
	func apexSwipeBack() -> some View {
		modifier(ApexSwipeBackModifier())
	}
}



