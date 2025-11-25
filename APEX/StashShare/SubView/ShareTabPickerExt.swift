//
//  ShareTabPickerExt.swift
//  StashShare
//
//  Extracted from ShareSheetView for reuse and organization.
//

import SwiftUI

struct ShareTabPickerExt: View {
    let selectedTab: ShareSheetViewModel.Tab
    let onSelect: (ShareSheetViewModel.Tab) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ShareSheetViewModel.Tab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        onSelect(tab)
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(tab.rawValue)
                            .font(selectedTab == tab ? .body1 : .body2)
                            .foregroundColor(selectedTab == tab ? ShareTheme.primary : .gray)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                        Rectangle()
                            .fill(selectedTab == tab ? ShareTheme.primary : .clear)
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.25), value: selectedTab)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .background(
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(ShareTheme.primaryContainer)
                    .frame(height: 2)
            }
        )
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .frame(height: 40)
    }
}


