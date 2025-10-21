//
//  ProfileAddView.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import SwiftUI

struct ProfileAddView: View {
    @State private var surname: String = ""
    @State private var name: String = ""
    
    @State private var company: String = ""
    @State private var department: String = ""
    @State private var position: String = ""
    
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var linkedinLink: String = ""
    
    @State private var memo: String = ""
    
    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    VStack(spacing: 10) {
                        Image("ProfileS")
                            .resizable()
                            .frame(width: 116, height: 116)
                        Text("프로필")
                            .font(.body5)
                    }
                    Spacer()
                    VStack(spacing: 9) {
                        Image("CardL")
                            .resizable()
                            .frame(width: 154, height: 92)
                            .padding(.vertical, 8)
                        Text("명함")
                            .font(.body5)
                    }
                }
                .padding(.bottom, 48)
                
                APEXTextField(style: .field, placeholder: "성", text: $surname)
                    .padding(.bottom, 8)
                    
                APEXTextField(style: .field, placeholder: "이름", text: $name)
                    .padding(.bottom, 40)
                
                APEXTextField(style: .field, placeholder: "회사", text: $company)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "부서", text: $department)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "직책", text: $position)
                    .padding(.bottom, 40)
                
                APEXTextField(style: .field, placeholder: "이메일", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(.bottom, 8)
                ContactPhoneInput(phone: $phoneNumber)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "링크드인 URL", text: $linkedinLink)
                    .padding(.bottom, 40)
                
                APEXTextField(style: .editor, label: "메모", placeholder: "주요 대화", text: $memo)
                
            }
            .padding(.horizontal, 16)
        }
        .padding(16)
    }
}

#Preview {
    ProfileAddView()
}
