//
//  NotesManagementNavigationBar.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesManagementNavigationBar: View {
    let isSelectionMode: Bool
    let onClose: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()

                Spacer(minLength: 0)

                Button(action: onComplete) {
                    Text("완료")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()
            }
            .frame(height: 44)
            .padding(.horizontal, 12)
            .background(Color("Background"))

            // Centered title
            Text("노트 관리")
                .font(.title5)
                .foregroundColor(.black)
                .lineLimit(1)
                .frame(height: 44)
                .padding(.horizontal, 12)
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    NotesManagementNavigationBar(
        isSelectionMode: false,
        onClose: {},
        onComplete: {}
    )
    .background(Color("Background"))
}