//
//  SwiftUIView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/28/25.
//

import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        Menu("옵션") {
            // ControlGroup 내부의 버튼들은 가로로 배치됩니다.
            ControlGroup {
                Button {
                    print("버튼 1 선택")
                } label: {
                    Label("버튼 1", systemImage: "1.circle.fill")
                }

                Button {
                    print("버튼 2 선택")
                } label: {
                    Label("버튼 2", systemImage: "2.circle.fill")
                }

                Button {
                    print("버튼 3 선택")
                } label: {
                    Label("버튼 3", systemImage: "3.circle.fill")
                }
            }
        }
    }
}
#Preview {
    SwiftUIView()
}
