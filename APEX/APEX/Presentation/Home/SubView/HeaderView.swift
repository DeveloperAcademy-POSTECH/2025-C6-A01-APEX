//
//  HeaderView.swift
//  APEX
//
//  Created by 조운경 on 10/11/25.
//

import SwiftUI

struct HeaderView: View {
    @Binding var showProfileAdd: Bool
    
    var body: some View {
        HStack {
            Text("Contacts")
                .font(.title3)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: {
                showProfileAdd.toggle()
            }, label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .glassEffect()
            })
        }
    }
}

#Preview {
    HeaderView(showProfileAdd: .constant(false))
}
