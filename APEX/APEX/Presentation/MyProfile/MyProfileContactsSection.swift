//
//  MyProfileContactsSection.swift
//  APEX
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

struct MyProfileContactsSection: View {
    var email: String?
    var phone: String?
    var linkedin: String?

    var onTapEmail: (String) -> Void
    var onTapPhone: (String) -> Void
    var onTapLinkedIn: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let email, !email.isEmpty {
                item(label: "이메일", value: email, isLink: true) {
                    onTapEmail(email)
                }
            }
            if let phone, !phone.isEmpty {
                item(label: "전화번호 / Mobile", value: phone, isLink: true) {
                    onTapPhone(phone)
                }
            }
            if let linkedin, !linkedin.isEmpty {
                item(label: "링크드인 URL", value: linkedin, isLink: true) {
                    onTapLinkedIn(linkedin)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func item(label: String, value: String, isLink: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.body6)
                .foregroundColor(.gray)

            Button(action: action) {
                Text(value)
                    .font(.body2)
                    .foregroundColor(isLink ? Color("Primary") : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    MyProfileContactsSection(
        email: "user@example.com",
        phone: "+82 010-2360-6221",
        linkedin: "https://linkedin.com/in/username"
    , onTapEmail: { _ in }, onTapPhone: { _ in }, onTapLinkedIn: { _ in })
    .padding()
    .background(Color("Background"))
}

