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
					withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) {
						selectedIndex = idx
						onSelect?(idx)
					}
				} label: {
					VStack(spacing: 8) {
						Text(items[idx])
							.font(.subheadline)
							.fontWeight(.semibold)
							.foregroundColor(selectedIndex == idx ? Color("Primary") : Color("BackgroundHover"))
						Rectangle()
							.fill(selectedIndex == idx ? Color("Primary") : Color("BackgroundHover"))
							.frame(height: selectedIndex == idx ? 4 : 2)
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 8)
				}
				.buttonStyle(.plain)
			}
		}
		.background(.white)
		.frame(height: 40)
	}
}

#Preview {
	@State var idx = 0
	return APEXUnderlineTabs(items: ["First", "Second"], selectedIndex: $idx)
}



