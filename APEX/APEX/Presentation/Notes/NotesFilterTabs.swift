//
//  NotesFilterTabs.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesFilterTabs: View {
    @Binding var selectedFilter: NotesFilter
    let availableFilters: [NotesFilterItem]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(availableFilters) { filterItem in
                    FilterTab(
                        title: filterItem.displayName,
                        isSelected: selectedFilter == filterItem.filter,
                        isEnabled: filterItem.isEnabled
                    ) {
                        if filterItem.isEnabled {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filterItem.filter
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

private struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Text(title)
                    .font(.body2)
                    .foregroundColor(textColor)
            }
            .buttonStyle(.plain)
            
            Rectangle()
                .fill(underlineColor)
                .frame(height: 2)
        }
        .frame(height: 32)
    }
    
    private var textColor: Color {
        // 선택되지 않은 탭도 파란 계열이 보이도록 BackgroundHover 사용
        if isSelected {
            return Color("Primary")
        } else {
            return Color("BackgroundHover")
        }
    }
    
    private var underlineColor: Color {
        if isSelected && isEnabled {
            return Color("Primary")
        } else {
            return Color.clear
        }
    }
}

#Preview {
    @Previewable @State var selectedFilter: NotesFilter = .all
    let filters: [NotesFilterItem] = [
        NotesFilterItem(filter: .all, isEnabled: true),
        NotesFilterItem(filter: .company("Apple"), isEnabled: true),
        NotesFilterItem(filter: .company("Apex"), isEnabled: true),
        NotesFilterItem(filter: .company("Google"), isEnabled: false)
    ]
    
    NotesFilterTabs(
        selectedFilter: $selectedFilter,
        availableFilters: filters
    )
    .background(Color("Background"))
}
