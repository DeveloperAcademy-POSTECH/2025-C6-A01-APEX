//
//  ProfileDetailView.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//


import SwiftUI

struct ProfileDetailView: View {
    @State private var memo = "태국 박람회에서 만남. 베트남/대만에 공장 있음. 한국에서 스타트업 기업들끼리 행사 주최할 예정"
    
    let user = ProfileUser(
        org: "애플코리아",
        name: "김하경",
        title: "전략기획 마케팅부 크리에이티브 디렉터",
        email: "karynkim@postech.ac.kr",
        phone: "+82 010-2360-6221",
        linkedin: "https://www.linkedin.com/in/...",
        avatar: "avatar"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: {}) { Image(systemName: "chevron.left") }
                Spacer()
                Text(user.org).font(.headline)
                Spacer()
                Button("편집", action: {}).foregroundColor(.gray)
            }.padding(.horizontal)

            HStack(alignment: .top, spacing: 16) {
                Button(action: {}) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.gray.opacity(0.4))
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(user.name)
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(user.title)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    Button(action: {}) {
                        Text("메모하기")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color(red: 0.16, green: 0.29, blue: 0.56))
                            .cornerRadius(8)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 120)
                .overlay(
                    HStack(spacing: 6){
                        Circle().fill(.gray).frame(width: 6)
                        Circle().fill(.gray.opacity(0.4)).frame(width: 6)
                    }.offset(y:40)
                )

            Group {
                Field(label: "이메일", value: user.email)
                Field(label: "전화번호 / Mobile", value: user.phone)
                Field(label: "링크드인 URL", value: user.linkedin)
                Text("메모").font(.caption).foregroundColor(.gray)
                TextEditor(text: $memo)
                    .frame(height: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                HStack { Spacer(); Text("\(memo.count)/100").font(.caption).foregroundColor(.gray) }
            }.padding(.horizontal)

            Spacer()
        }
    }
}

struct Field: View {
    let label, value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.gray)
            Text(value).font(.body).lineLimit(1)
            Divider()
        }
    }
}

struct ProfileUser {
    let org, name, title, email, phone, linkedin, avatar: String
}




#Preview {
    ProfileDetailView()
}
