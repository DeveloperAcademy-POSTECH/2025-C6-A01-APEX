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
    
    // MARK: - Helper Methods
    /// 현재 필터가 특정 회사와 매치되는지 확인
    func matches(company: String) -> Bool {
        switch self {
        case .all:
            return true
        case .company(let filterCompany):
            return filterCompany.trimmingCharacters(in: .whitespacesAndNewlines) == 
                   company.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// 필터 적용 여부 확인
    var isFiltering: Bool {
        switch self {
        case .all:
            return false
        case .company:
            return true
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
    
    // MARK: - Initializers
    init(filter: NotesFilter, isEnabled: Bool = true) {
        self.filter = filter
        self.isEnabled = isEnabled
    }
}