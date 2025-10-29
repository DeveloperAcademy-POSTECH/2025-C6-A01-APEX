//
//  NotesFilter.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import Foundation

enum NotesFilter: Hashable {
    case all
    case company(String)
    
    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .company(let name):
            return name
        }
    }
}

struct NotesFilterItem: Identifiable, Hashable {
    let id = UUID()
    let filter: NotesFilter
    let isEnabled: Bool
    
    var displayName: String {
        filter.displayName
    }
}