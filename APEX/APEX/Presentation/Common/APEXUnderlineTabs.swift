//
//  APEXUnderlineTabs.swift
//  APEX
//
//  Created by AI Assistant on 11/08/25.
//

import SwiftUI

struct APEXUnderlineTabs: View {
	let items: [String]
	@Binding var selectedIndex: Int
	var onSelect: ((Int) -> Void)?

	var body: some View {
		HStack(spacing: 0) {
			ForEach(items.indices, id: \.self) { idx in
				Button {
					withAnimation(.easeInOut(duration: 0.25)) {
						selectedIndex = idx
						onSelect?(idx)
					}
				} label: {
					VStack(spacing: 0) {
						Text(items[idx])
							.font(selectedIndex == idx ? .body1 : .body2)
							.foregroundColor(selectedIndex == idx ? Color("Primary") : Color("BackgroundDisabled"))
							.padding(.horizontal, 20)
							.padding(.vertical, 8)
						Rectangle()
							.fill(selectedIndex == idx ? Color("Primary") : Color.clear)
							.frame(height: 4)
							.animation(.easeInOut(duration: 0.25), value: selectedIndex)
					}
					.frame(maxWidth: .infinity)
				}
				.buttonStyle(.plain)
			}
		}
        .padding(.horizontal, 10)
		.background(
			VStack {
				Spacer()
				Rectangle()
					.fill(Color("PrimaryContainer"))
					.frame(height: 2)
			}
		)
		.animation(.easeInOut(duration: 0.25), value: selectedIndex)
		.frame(height: 40)
	}
}

#Preview {
	@State var idx = 0
	return APEXUnderlineTabs(items: ["First", "Second"], selectedIndex: $idx)
}

