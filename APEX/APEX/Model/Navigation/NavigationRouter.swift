//
//  AppRouter.swift
//  APEX
//
//  Created by AI Assistant on 11/9/25.
//

import SwiftUI
import Combine

@MainActor
final class NavigationRouter: ObservableObject {
	@Published var path: [NavigationDestination] = []
	
	// MARK: - Navigation API
	func push(_ route: NavigationDestination) {
		path.append(route)
	}
	
	func replace(with route: NavigationDestination) {
		if path.isEmpty {
			path = [route]
		} else {
			path.removeLast()
			path.append(route)
		}
	}
	
	func setPath(_ newPath: [NavigationDestination]) {
		path = newPath
	}
	
	func pop() {
		_ = path.popLast()
	}
	
	func popToRoot() {
		path.removeAll()
	}
}


