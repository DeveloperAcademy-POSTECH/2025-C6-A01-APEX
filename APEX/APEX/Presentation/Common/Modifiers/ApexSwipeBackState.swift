//
//  ApexSwipeBackState.swift
//  APEX
//
//  Created by AI Assistant on 11/17/25.
//

import Foundation

final class ApexSwipeBackState {
	static let shared = ApexSwipeBackState()
	private init() {}
	
	// When true, the global swipe-back gesture should be ignored.
	var isDisabled: Bool = false
}



