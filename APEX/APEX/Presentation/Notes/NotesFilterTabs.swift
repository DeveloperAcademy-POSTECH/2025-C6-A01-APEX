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
                        // 비활성화된 필터도 클릭은 가능하지만 아무 동작 안함
                        if filterItem.isEnabled {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filterItem.filter
                            }
                        }
                        // 비활성화된 경우 아무것도 하지 않음
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
            // .disabled(!isEnabled) // 제거 - 비활성화된 상태에서도 클릭 가능
            
            // 밑줄
            Rectangle()
                .fill(underlineColor)
                .frame(height: 2)
        }
        .frame(height: 32)
    }
    
    private var textColor: Color {
        if !isEnabled {
            return Color("Gray")  // 비활성화 상태도 회색 (BackgroundHover 대신)
        } else if isSelected {
            return Color("Primary")  // 선택된 상태
        } else {
            return Color("Gray")  // 기본 상태
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
        NotesFilterItem(filter: .company("APEX"), isEnabled: true),
        NotesFilterItem(filter: .company("Google"), isEnabled: false)  // 비활성화 예시
    ]
    
    NotesFilterTabs(
        selectedFilter: $selectedFilter,
        availableFilters: filters
    )
    .background(Color("Background"))
}