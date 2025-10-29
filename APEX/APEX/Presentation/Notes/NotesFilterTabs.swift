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
        VStack(spacing: 0) {
            // 필터 탭들
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(availableFilters) { filterItem in
                        FilterTab(
                            title: filterItem.displayName,
                            isSelected: selectedFilter == filterItem.filter,
                            isEnabled: filterItem.isEnabled
                        ) {
                            if filterItem.isEnabled {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedFilter = filterItem.filter
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)  // 전체 탭들에 좌우 패딩 16씩 추가
            }
            .padding(.top, 12)
            .background(
                // 구분선을 배경으로 넣어서 뒤쪽에 배치
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color("BackgroundHover"))
                        .frame(height: 2)
                }
            )
        }
    }
}

private struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // 텍스트 영역 (상하 패딩 8, 좌우 패딩 20)
                Text(title)
                    .font(isSelected ? .body1 : .body2)  // 선택 상태에 따른 폰트
                    .foregroundColor(textColor)
                    .opacity(isEnabled ? 1.0 : 0.5)
                    .padding(.horizontal, 20)  // 좌우 패딩 20
                    .padding(.vertical, 8)     // 상하 패딩 8
                
                // 선택된 탭의 언더라인 (높이 4, Primary) - 회색선을 덮어버림
                Rectangle()
                    .fill(underlineColor)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.25), value: isSelected)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .frame(height: 40)  // 높이 40 유지
    }
    
    private var textColor: Color {
        if isSelected {
            return Color("Primary")
        } else {
            return Color("BackgroundHover")
        }
    }
    
    private var underlineColor: Color {
        if isSelected && isEnabled {
            return Color("Primary")  // 언더라인은 Primary 색상으로 회색선을 가림
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
        NotesFilterItem(filter: .company("Apex"), isEnabled: true)
    ]
    
    NotesFilterTabs(
        selectedFilter: $selectedFilter,
        availableFilters: filters
    )
    .background(Color("Background"))
}
