//
//  AppRoute.swift
//  APEX
//
//  Created by AI Assistant on 11/9/25.
//

import Foundation

enum NavigationDestination: Hashable, Codable {
	case chat(UUID)
	case chatArchive(UUID)
	case chatDetail(UUID)
	case profileDetail(UUID)
	case myProfile
	case archiveSection(UUID, NavigationArchiveSection)
	case unsubscribe
	case dataManagement
	case notesManagement
	case onboarding
	case profileAdd
}

enum NavigationArchiveSection: String, Codable, Hashable {
	case media, files, links, audio
}


