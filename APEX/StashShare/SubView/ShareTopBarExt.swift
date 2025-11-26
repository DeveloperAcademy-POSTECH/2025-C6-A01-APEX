//
//  ShareTopBarExt.swift
//  StashShare
//
//  Extracted from ShareSheetView for reuse and organization.
//

import SwiftUI

struct ShareTopBarExt: View {
    let title: String
    let selectedCount: Int
    let onClose: () -> Void
    let onSearch: () -> Void
    
    init(
        title: String,
        selectedCount: Int,
        onClose: @escaping () -> Void,
        onSearch: @escaping () -> Void
    ) {
        self.title = title
        self.selectedCount = selectedCount
        self.onClose = onClose
        self.onSearch = onSearch
    }
    
    private var background: Color = Color("Background")
    private var foreground: Color = .black
    private var height: CGFloat = 52
    
    var body: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foreground)
                        .frame(width: 44, height: 44)
                        .glassEffect()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("닫기"))
                
                Spacer(minLength: 0)
                
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foreground)
                        .frame(width: 44, height: 44)
                        .glassEffect()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("검색"))
            }
            .frame(height: height)
            .padding(.horizontal, 12)
            
            VStack(spacing: 0) {
                Text(title)
                    .lineLimit(1)
                    .font(.title5)
                    .foregroundColor(foreground)
                if selectedCount > 0 {
                    Text("\(selectedCount)명")
                        .lineLimit(1)
                        .font(.caption2)
                        .foregroundColor(ShareTheme.primary)
                }
            }
            .frame(height: height)
            .padding(.horizontal, 12)
            .allowsHitTesting(false)
        }
        .padding(.vertical, 8)
        .background(ShareTheme.background)
    }
}


