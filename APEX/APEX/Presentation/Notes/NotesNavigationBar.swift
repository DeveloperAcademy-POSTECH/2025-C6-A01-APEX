//
//  NotesNavigationBar.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesNavigationBar: View {
    let onMenuTap: () -> Void
    
    private enum Metrics {
        static let barHeight: CGFloat = 44
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        static let buttonSize: CGFloat = 44
        static let iconSize: CGFloat = 20
    }
    
    var body: some View {
        HStack {
            Text("Notes")
                .font(.title1)
                .foregroundColor(Color("Dark"))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: onMenuTap) {
                Image(systemName: "ellipsis")
                    .font(.system(size: Metrics.iconSize, weight: .semibold))
                    .foregroundColor(Color("Dark"))
                    .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: Metrics.barHeight)
        .padding(.horizontal, Metrics.horizontalPadding)
        .padding(.vertical, Metrics.verticalPadding)
        .background(Color("Background"))
    }
}

#Preview {
    NotesNavigationBar {
        print("Menu tapped")
    }
}