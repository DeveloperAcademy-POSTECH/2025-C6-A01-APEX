//
//  ShareSearchBarExt.swift
//  StashShare
//
//  Extracted from ShareSheetView for reuse and organization.
//

import SwiftUI

// MARK: - Search Bar (for ShareSheetView)
struct ShareSearchBarExt: View {
    @Binding var text: String
    var onClose: () -> Void
    @FocusState private var isFocused: Bool
    
    init(text: Binding<String>, onClose: @escaping () -> Void) {
        self._text = text
        self.onClose = onClose
    }
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                TextField("검색", text: $text)
                    .font(.body5)
                    .foregroundColor(.primary)
                    .focused($isFocused)
                    .submitLabel(.search)
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(ShareTheme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            Button("취소") {
                onClose()
            }
            .font(.callout)
            .foregroundColor(ShareTheme.primary)
            .buttonStyle(.plain)
        }
        .onAppear { isFocused = true }
    }
}


