//
//  NotesManagementTabSelector.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesManagementTabSelector: View {
    @Binding var selectedFilter: NotesFilter
    let availableFilters: [NotesFilterItem]
    
    var body: some View {
        VStack(spacing: 0) {
            NotesFilterTabs(
                selectedFilter: $selectedFilter,
                availableFilters: availableFilters
            )
        }
    }
}

#Preview {
    @State var selectedFilter: NotesFilter = .all
    let filters: [NotesFilterItem] = [
        NotesFilterItem(filter: .all, isEnabled: true),
        NotesFilterItem(filter: .company("Apple"), isEnabled: true),
        NotesFilterItem(filter: .company("Apex"), isEnabled: true)
    ]
    return NotesManagementTabSelector(
        selectedFilter: $selectedFilter,
        availableFilters: filters
    )
    .background(Color("Background"))
}