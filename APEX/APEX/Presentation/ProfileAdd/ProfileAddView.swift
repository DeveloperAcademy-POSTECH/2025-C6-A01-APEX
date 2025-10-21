//
//  ProfileAddView.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import SwiftUI

struct ProfileAddView: View {
    @State private var profile: UIImage? = nil
    @State private var card: UIView? = nil
    @State private var surname: String = ""
    @State private var name: String = ""
    @State private var company: String = ""
    @State private var department: String = ""
    @State private var position: String = ""
    @State private var email: String = ""
    @State private var contact: String = ""
    @State private var linkedinLink: String = ""
    @State private var memo: String = ""
    
    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    VStack(spacing: 10) {
                        Image("ProfileS")
                        Text("프로필")
                            .font(.body5)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 13) {
                        Image("CardS")
                        Text("명함")
                            .font(.body5)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 48)
                
                APEXTextField(style: .field, placeholder: "성", text: $surname)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "이름", text: $name)
                    .padding(.bottom, 48)
                
                APEXTextField(style: .field, placeholder: "회사", text: $company)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "부서", text: $department)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "직책", text: $position)
                    .padding(.bottom, 48)
                
                APEXTextField(style: .field, placeholder: "이메일", text: $email)
                    .padding(.bottom, 8)
                ContactsField(phone: $contact, placeholder: "연락처", isRegionInteractive: true)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "링크드인 URL", text: $linkedinLink)
                    .padding(.bottom, 48)
                
                APEXTextField(style: .editor, label: "메모", placeholder: "주요 대화", text: $memo, maxLength: 200)
                    .padding(.bottom, 48)
                
                Button {
                    
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color("Primary"))
                        Text("항목 수정하기")
                            .font(.body2)
                            .foregroundColor(Color("Primary"))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
                    .background(Color("PrimaryContainer"))
                    .cornerRadius(4)
                }
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 24)
        }
        .safeAreaInset(edge: .top) {
            APEXSheetTopBar(title: "연락처 추가", rightTitle: "완료", onRightTap: {
            }, onClose: {
            })
        }
    }
}

#Preview {
    ProfileAddView()
}
